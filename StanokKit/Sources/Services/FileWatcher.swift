import CoreServices
import Foundation

@MainActor
final class FileWatcher {

    private final class Context: @unchecked Sendable {

        let generation: Int

        private let lock = NSLock()

        private let scheduleDelivery: @Sendable () -> Void

        private let gitDirectory: String?

        private var pendingDirectories: Set<URL> = []

        private var pendingNeedsFullRescan = false

        private var pendingGitChange = false

        private var deliveryScheduled = false

        init(
            generation: Int,
            gitDirectory: String?,
            scheduleDelivery: @escaping @Sendable () -> Void
        ) {
            self.generation = generation
            self.gitDirectory = gitDirectory
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

                if let gitDirectory, path.hasPrefix(gitDirectory) {
                    if FileWatcher.isRelevantGitEvent(path, gitDirectory: gitDirectory) {
                        pendingGitChange = true
                    }
                    continue
                }

                let url = URL(filePath: path)
                guard !FileWatcher.isIgnored(url) else { continue }

                pendingDirectories.insert(url.deletingLastPathComponent())
                pendingGitChange = true
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
    }

    private enum PathFilters {

        static let relevantGit: Set<String> = [
            "HEAD", "index", "MERGE_HEAD", "ORIG_HEAD", "logs/HEAD"
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

    private let onDirectoriesChanged: (Set<URL>) -> Void

    private let onGitChange: () -> Void

    private var stream: FSEventStreamRef?

    private var context: Context?

    private var pendingDirectories: Set<URL> = []

    private var directoriesFlush: Task<Void, Never>?

    private var gitFlush: Task<Void, Never>?

    private var nextGeneration = 0

    private var watchedRoot: URL?

    init(onDirectoriesChanged: @escaping (Set<URL>) -> Void, onGitChange: @escaping () -> Void) {
        self.onDirectoriesChanged = onDirectoriesChanged
        self.onGitChange = onGitChange
    }

    private nonisolated static func isIgnored(_ url: URL) -> Bool {
        IgnoredPaths.contains(url)
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

    func watch(_ url: URL, gitDirectory: String?) {
        stop()

        nextGeneration += 1
        let currentGeneration = nextGeneration
        watchedRoot = url

        let scheduleDelivery: @Sendable () -> Void = { [weak self] in
            Task { @MainActor in self?.deliver(generation: currentGeneration) }
        }
        let context = Context(
            generation: currentGeneration,
            gitDirectory: gitDirectory,
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

        let paths = gitDirectory.map { [url.path(percentEncoded: false), $0] }
            ?? [url.path(percentEncoded: false)]

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
            return
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
            return
        }
    }

    func stop() {
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

    private func deliver(generation delivered: Int) {
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

    private func scheduleDirectoriesFlush() {
        directoriesFlush?.cancel()
        directoriesFlush = Task { [weak self] in
            try? await Task.sleep(for: FlushDelay.directories)
            guard !Task.isCancelled else { return }

            self?.emitDirectories()
        }
    }

    private func scheduleGitFlush() {
        gitFlush?.cancel()
        gitFlush = Task { [weak self] in
            try? await Task.sleep(for: FlushDelay.git)
            guard !Task.isCancelled else { return }

            self?.emitGitChange()
        }
    }

    private func emitDirectories() {
        let directories = pendingDirectories
        pendingDirectories.removeAll()
        onDirectoriesChanged(directories)
    }

    private func emitGitChange() {
        onGitChange()
    }
}
