import CoreServices
import Foundation

@MainActor
public final class FileWatcher {

    private final class Context: @unchecked Sendable {

        let generation: Int

        private var pendingDirectories: Set<URL> = []
        private var pendingNeedsFullRescan = false
        private var pendingGitChange = false
        private var deliveryScheduled = false

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
                    pendingGitChange = true
                    continue
                }

                if
                    let owner = gitDirectories.first(where: {
                        FileWatcher.isInside(path, gitDirectory: $0)
                    }) {
                    if FileWatcher.isRelevantGitEvent(path, gitDirectory: owner) {
                        pendingGitChange = true
                    }
                    continue
                }

                pendingGitChange = true

                let url = URL(filePath: path)
                guard !FileWatcher.isIgnored(url, under: root) else { continue }

                pendingDirectories.insert(url.deletingLastPathComponent())
            }

            let alreadyScheduled = deliveryScheduled
            deliveryScheduled = true
            lock.unlock()

            guard !alreadyScheduled else { return }

            scheduleDelivery()
        }

        func drain() -> (directories: Set<URL>, needsFullRescan: Bool, gitChanged: Bool) {
            lock.lock()
            defer { lock.unlock() }

            let directories = pendingDirectories
            let needsFullRescan = pendingNeedsFullRescan
            let gitChanged = pendingGitChange
            pendingDirectories.removeAll()
            pendingNeedsFullRescan = false
            pendingGitChange = false
            deliveryScheduled = false
            return (directories, needsFullRescan, gitChanged)
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

    private nonisolated static func isIgnored(_ url: URL, under root: String) -> Bool {
        IgnoredPaths.contains(url, under: URL(filePath: root))
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
            root: url.path(percentEncoded: false),
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
        guard !drained.directories.isEmpty || drained.needsFullRescan || drained.gitChanged else {
            return
        }

        if !drained.directories.isEmpty || drained.needsFullRescan {
            pendingDirectories.formUnion(drained.directories)
            if drained.needsFullRescan, let watchedRoot {
                pendingDirectories.insert(watchedRoot)
            }
            scheduleDirectoriesFlush()
        }

        if drained.gitChanged {
            scheduleGitFlush()
        }
    }

    func scheduleDirectoriesFlush() {
        directoriesFlush?.cancel()
        directoriesFlush = Task { [weak self] in
            try? await Task.sleep(for: FlushDelay.directories)
            guard !Task.isCancelled else { return }

            self?.emitDirectories()
        }
    }

    func scheduleGitFlush() {
        if let gitFlushStartedAt, Date().timeIntervalSince(gitFlushStartedAt) >= FlushDelay.gitCap {
            emitGitChange()
            return
        }

        if gitFlushStartedAt == nil { gitFlushStartedAt = Date() }

        gitFlush?.cancel()
        gitFlush = Task { [weak self] in
            try? await Task.sleep(for: FlushDelay.git)
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
        onGitChange()
    }
}
