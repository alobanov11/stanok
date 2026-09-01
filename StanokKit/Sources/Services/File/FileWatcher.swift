import CoreServices
import Foundation

@MainActor
public final class FileWatcher {

    private enum GitWindow {

        case armed
        case expired
        case kept
    }

    private struct Pending {

        enum Git: Int, Comparable {

            case none
            case ignoredOnly
            case changed

            static func < (lhs: Git, rhs: Git) -> Bool {
                lhs.rawValue < rhs.rawValue
            }
        }

        var isEmpty: Bool {
            directories.isEmpty && !needsFullRescan && git == .none
        }

        let directories: Set<URL>
        let needsFullRescan: Bool
        let git: Git
    }

    private final class Context: @unchecked Sendable {

        let generation: Int

        private var pendingDirectories: Set<URL> = []
        private var pendingNeedsFullRescan = false
        private var deliveryScheduled = false
        private var pendingGit = Pending.Git.none

        private let lock = NSLock()
        private let scheduleDelivery: @Sendable () -> Void
        private let gitDirectories: [String]
        private let root: String

        init(
            generation: Int,
            gitDirectories: [String],
            root: String,
            scheduleDelivery: @escaping @Sendable () -> Void
        ) {
            self.generation = generation
            self.gitDirectories = gitDirectories
            self.root = root
            self.scheduleDelivery = scheduleDelivery
        }

        func record(_ paths: [String], flags: [FSEventStreamEventFlags]) {
            let rescanMask = FSEventStreamEventFlags(
                kFSEventStreamEventFlagMustScanSubDirs
                    | kFSEventStreamEventFlagUserDropped
                    | kFSEventStreamEventFlagKernelDropped
            )

            lock.lock()
            for (index, path) in paths.enumerated() {
                if flags[index] & rescanMask != 0 {
                    pendingNeedsFullRescan = true
                    pendingGit = .changed
                    continue
                }

                let owner = gitDirectories
                    .filter { FileWatcher.isInside(path, gitDirectory: $0) }
                    .max { $0.count < $1.count }

                if let owner {
                    if FileWatcher.isRelevantGitEvent(path, gitDirectory: owner) {
                        pendingGit = .changed
                    }
                    continue
                }

                guard !FileWatcher.isIgnored(path, under: root) else {
                    pendingGit = max(pendingGit, .ignoredOnly)
                    continue
                }

                pendingGit = .changed
                pendingDirectories.insert(URL(filePath: path).deletingLastPathComponent())
            }

            let alreadyScheduled = deliveryScheduled
            deliveryScheduled = true
            lock.unlock()

            guard !alreadyScheduled else { return }

            scheduleDelivery()
        }

        func drain() -> Pending {
            lock.lock()
            defer { lock.unlock() }

            let drained = Pending(
                directories: pendingDirectories,
                needsFullRescan: pendingNeedsFullRescan,
                git: pendingGit
            )
            pendingDirectories.removeAll()
            pendingNeedsFullRescan = false
            pendingGit = .none
            deliveryScheduled = false

            return drained
        }
    }

    private enum ContextMemory {

        static let retain: @convention(c) (UnsafeRawPointer?) -> UnsafeRawPointer? = { info in
            guard let info else { return nil }

            let value = Unmanaged<Context>.fromOpaque(info).takeUnretainedValue()
            return UnsafeRawPointer(Unmanaged.passRetained(value).toOpaque())
        }

        static let release: @convention(c) (UnsafeRawPointer?) -> Void = { info in
            guard let info else { return }

            _ = Unmanaged<Context>.fromOpaque(info).takeRetainedValue()
        }
    }

    private enum FlushDelay {

        static let directories = Duration.milliseconds(150)
        static let git = Duration.milliseconds(300)
        static let gitCap: TimeInterval = 2
        static let ignoredGit = Duration.seconds(10)
        static let ignoredGitCap: TimeInterval = 10
    }

    private enum PathFilters {

        static let relevantGit: Set<String> = [
            "HEAD", "index", "MERGE_HEAD", "ORIG_HEAD", "logs/HEAD",
            "FETCH_HEAD", "packed-refs", "config"
        ]
    }

    private static let callback: FSEventStreamCallback = { _, info, count, paths, flags, _ in
        guard
            let info,
            let list = unsafeBitCast(paths, to: NSArray.self) as? [String]
        else { return }

        let eventFlags = Array(UnsafeBufferPointer(start: flags, count: count))
        Unmanaged<Context>.fromOpaque(info).takeUnretainedValue().record(list, flags: eventFlags)
    }

    private nonisolated(unsafe) var stream: FSEventStreamRef?

    private var context: Context?
    private var pendingDirectories: Set<URL> = []
    private var directoriesFlush: Task<Void, Never>?
    private var gitFlush: Task<Void, Never>?
    private var gitFlushStartedAt: Date?
    private var gitFlushCap: TimeInterval = FlushDelay.gitCap
    private var nextGeneration = 0
    private var watchedRoot: URL?

    private let onDirectoriesChanged: (Set<URL>) -> Void
    private let onGitChange: () -> Void

    public init(
        onDirectoriesChanged: @escaping (Set<URL>) -> Void,
        onGitChange: @escaping () -> Void
    ) {
        self.onDirectoriesChanged = onDirectoriesChanged
        self.onGitChange = onGitChange
    }

    deinit {
        guard let stream else { return }

        FSEventStreamStop(stream)
        FSEventStreamInvalidate(stream)
        FSEventStreamRelease(stream)
    }

    private nonisolated static func isIgnored(_ path: String, under root: String) -> Bool {
        IgnoredPaths.contains(path: path, underResolvedRoot: root)
    }

    private nonisolated static func isInside(_ path: String, gitDirectory: String) -> Bool {
        path == gitDirectory || path.hasPrefix(gitDirectory + "/")
    }

    private nonisolated static func isRelevantGitEvent(
        _ path: String,
        gitDirectory: String
    ) -> Bool {
        var relative = String(path.dropFirst(gitDirectory.count))
        if relative.hasPrefix("/") { relative.removeFirst() }

        guard !relative.isEmpty, !relative.hasSuffix(".lock") else { return false }
        if PathFilters.relevantGit.contains(relative) { return true }

        return relative.hasPrefix("refs/")
    }

    @discardableResult
    public func watch(_ url: URL, gitDirectories: [String] = []) -> Bool {
        stop()

        nextGeneration += 1
        let currentGeneration = nextGeneration
        watchedRoot = url

        let scheduleDelivery: @Sendable () -> Void = { [weak self] in
            Task { @MainActor in self?.deliver(generation: currentGeneration) }
        }
        let unique = Array(Set(gitDirectories))
        let context = Context(
            generation: currentGeneration,
            gitDirectories: unique,
            root: url.resolvingSymlinksInPath().path(percentEncoded: false),
            scheduleDelivery: scheduleDelivery
        )
        self.context = context

        var streamContext = FSEventStreamContext(
            version: 0,
            info: Unmanaged.passUnretained(context).toOpaque(),
            retain: ContextMemory.retain,
            release: ContextMemory.release,
            copyDescription: nil
        )

        let flags = UInt32(
            kFSEventStreamCreateFlagFileEvents
                | kFSEventStreamCreateFlagNoDefer
                | kFSEventStreamCreateFlagUseCFTypes
        )

        let paths = [url.path(percentEncoded: false)] + unique

        stream = FSEventStreamCreate(
            kCFAllocatorDefault,
            Self.callback,
            &streamContext,
            paths as CFArray,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            0.2,
            flags
        )

        guard let stream else {
            self.context = nil
            return false
        }

        let exclusions = IgnoredPaths.homeExclusions
        if !exclusions.isEmpty {
            FSEventStreamSetExclusionPaths(stream, exclusions as CFArray)
        }

        FSEventStreamSetDispatchQueue(stream, DispatchQueue.global(qos: .utility))

        guard FSEventStreamStart(stream) else {
            Log.terminal.error(
                "failed to start FSEventStream at \(url.path(percentEncoded: false))"
            )
            FSEventStreamInvalidate(stream)
            FSEventStreamRelease(stream)
            self.stream = nil
            self.context = nil
            return false
        }

        return true
    }

    public func stop() {
        directoriesFlush?.cancel()
        directoriesFlush = nil
        gitFlush?.cancel()
        gitFlush = nil
        gitFlushStartedAt = nil
        gitFlushCap = FlushDelay.gitCap
        pendingDirectories.removeAll()
        context = nil

        guard let stream else { return }

        FSEventStreamStop(stream)
        FSEventStreamInvalidate(stream)
        FSEventStreamRelease(stream)
        self.stream = nil
    }
}

private extension FileWatcher {

    func deliver(generation delivered: Int) {
        guard let context, context.generation == delivered else { return }

        let drained = context.drain()
        guard !drained.isEmpty else { return }

        scheduleDirectories(drained)

        switch drained.git {
        case .none: break
        case .changed: scheduleGitFlush(ignoredOnly: false)
        case .ignoredOnly: scheduleGitFlush(ignoredOnly: true)
        }
    }

    private func scheduleDirectories(_ drained: Pending) {
        guard !drained.directories.isEmpty || drained.needsFullRescan else { return }

        pendingDirectories.formUnion(drained.directories)

        if drained.needsFullRescan, let watchedRoot {
            pendingDirectories.insert(watchedRoot)
        }

        scheduleDirectoriesFlush()
    }

    func scheduleDirectoriesFlush() {
        directoriesFlush?.cancel()
        directoriesFlush = Task { [weak self] in
            try? await Task.sleep(for: FlushDelay.directories)
            guard !Task.isCancelled else { return }

            self?.emitDirectories()
        }
    }

    func scheduleGitFlush(ignoredOnly: Bool) {
        let cap = ignoredOnly ? FlushDelay.ignoredGitCap : FlushDelay.gitCap

        switch openGitWindow(cap: cap, ignoredOnly: ignoredOnly) {
        case .kept:
            return

        case .expired:
            gitFlush?.cancel()
            gitFlush = nil
            emitGitChange()

        case .armed:
            armGitFlush(ignoredOnly: ignoredOnly)
        }
    }

    private func openGitWindow(cap: TimeInterval, ignoredOnly: Bool) -> GitWindow {
        guard let startedAt = gitFlushStartedAt else {
            gitFlushStartedAt = Date()
            gitFlushCap = cap

            return .armed
        }

        gitFlushCap = min(gitFlushCap, cap)
        guard Date().timeIntervalSince(startedAt) < gitFlushCap else { return .expired }

        // Почему: взведённый таймер настоящей правки нельзя отодвигать шумом сборки
        guard !ignoredOnly || gitFlush == nil else { return .kept }

        return .armed
    }

    func armGitFlush(ignoredOnly: Bool) {
        let delay = ignoredOnly ? FlushDelay.ignoredGit : FlushDelay.git

        gitFlush?.cancel()
        gitFlush = Task { [weak self] in
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled else { return }

            self?.emitGitChange()
        }
    }

    func emitDirectories() {
        let directories = pendingDirectories
        pendingDirectories.removeAll()
        onDirectoriesChanged(directories)
    }

    func emitGitChange() {
        gitFlushStartedAt = nil
        gitFlushCap = FlushDelay.gitCap
        onGitChange()
    }
}
