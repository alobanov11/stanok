import CoreServices
import Foundation

@MainActor
final class FileWatcher {

    private final class Context: @unchecked Sendable {

        let generation: Int

        private let lock = NSLock()

        private let scheduleDelivery: @Sendable () -> Void

        private var pendingDirectories: Set<URL> = []

        private var pendingNeedsFullRescan = false

        private var deliveryScheduled = false

        init(generation: Int, scheduleDelivery: @escaping @Sendable () -> Void) {
            self.generation = generation
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
                    continue
                }

                let url = URL(filePath: path)
                guard !FileWatcher.isIgnored(url) else { continue }

                pendingDirectories.insert(url.deletingLastPathComponent())
            }

            let alreadyScheduled = deliveryScheduled
            deliveryScheduled = true
            lock.unlock()

            guard !alreadyScheduled else { return }

            scheduleDelivery()
        }

        func drain() -> (directories: Set<URL>, needsFullRescan: Bool) {
            lock.lock()
            defer { lock.unlock() }

            let directories = pendingDirectories
            let needsFullRescan = pendingNeedsFullRescan
            pendingDirectories.removeAll()
            pendingNeedsFullRescan = false
            deliveryScheduled = false
            return (directories, needsFullRescan)
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

    private nonisolated static let ignored: Set<String> = [
        ".git", "node_modules", ".build", "DerivedData", ".next", ".venv", "Pods", ".zig-cache"
    ]

    private static let callback: FSEventStreamCallback = { _, info, count, paths, flags, _ in
        guard
            let info,
            let list = unsafeBitCast(paths, to: NSArray.self) as? [String]
        else { return }

        let eventFlags = Array(UnsafeBufferPointer(start: flags, count: count))
        Unmanaged<Context>.fromOpaque(info).takeUnretainedValue().record(list, flags: eventFlags)
    }

    private let onChange: (Set<URL>) -> Void

    private var stream: FSEventStreamRef?

    private var context: Context?

    private var pending: Set<URL> = []

    private var flush: Task<Void, Never>?

    private var nextGeneration = 0

    private var watchedRoot: URL?

    init(onChange: @escaping (Set<URL>) -> Void) {
        self.onChange = onChange
    }

    private nonisolated static func isIgnored(_ url: URL) -> Bool {
        url.pathComponents.contains { ignored.contains($0) }
    }

    func watch(_ url: URL) {
        stop()

        nextGeneration += 1
        let currentGeneration = nextGeneration
        watchedRoot = url

        let context = Context(generation: currentGeneration) { [weak self] in
            Task { @MainActor in self?.deliver(generation: currentGeneration) }
        }
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

        stream = FSEventStreamCreate(
            kCFAllocatorDefault,
            Self.callback,
            &streamContext,
            [url.path(percentEncoded: false)] as CFArray,
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
        flush?.cancel()
        flush = nil
        pending.removeAll()
        context = nil

        guard let stream else { return }

        FSEventStreamStop(stream)
        FSEventStreamInvalidate(stream)
        FSEventStreamRelease(stream)
        self.stream = nil
    }

    private func deliver(generation delivered: Int) {
        guard let context, context.generation == delivered else { return }

        let (directories, needsFullRescan) = context.drain()
        guard !directories.isEmpty || needsFullRescan else { return }

        pending.formUnion(directories)
        if needsFullRescan, let watchedRoot {
            pending.insert(watchedRoot)
        }

        flush?.cancel()
        flush = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(150))
            guard !Task.isCancelled else { return }

            self?.emit()
        }
    }

    private func emit() {
        let directories = pending
        pending.removeAll()
        onChange(directories)
    }
}
