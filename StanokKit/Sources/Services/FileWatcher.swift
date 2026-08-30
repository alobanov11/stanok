import CoreServices
import Foundation

@MainActor
final class FileWatcher {

    private final class Context: Sendable {

        let handler: @Sendable ([String]) -> Void

        init(handler: @escaping @Sendable ([String]) -> Void) {
            self.handler = handler
        }
    }

    private static let ignored: Set<String> = [
        ".git", "node_modules", ".build", "DerivedData", ".next", ".venv", "Pods", ".zig-cache"
    ]

    private static let callback: FSEventStreamCallback = { _, info, _, paths, _, _ in
        guard
            let info,
            let list = unsafeBitCast(paths, to: NSArray.self) as? [String]
        else { return }

        Unmanaged<Context>.fromOpaque(info).takeUnretainedValue().handler(list)
    }

    private let onChange: (Set<URL>) -> Void

    private var stream: FSEventStreamRef?

    private var context: Context?

    private var pending: Set<URL> = []

    private var flush: Task<Void, Never>?

    init(onChange: @escaping (Set<URL>) -> Void) {
        self.onChange = onChange
    }

    private static func isIgnored(_ url: URL) -> Bool {
        url.pathComponents.contains { ignored.contains($0) }
    }

    func watch(_ url: URL) {
        stop()

        let context = Context { [weak self] paths in
            Task { @MainActor in self?.received(paths) }
        }
        self.context = context

        var streamContext = FSEventStreamContext(
            version: 0,
            info: Unmanaged.passUnretained(context).toOpaque(),
            retain: nil,
            release: nil,
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

        guard let stream else { return }

        FSEventStreamSetDispatchQueue(stream, DispatchQueue.global(qos: .utility))
        FSEventStreamStart(stream)
    }

    func stop() {
        flush?.cancel()
        flush = nil
        pending.removeAll()

        guard let stream else { return }

        FSEventStreamStop(stream)
        FSEventStreamInvalidate(stream)
        FSEventStreamRelease(stream)
        self.stream = nil
        context = nil
    }

    private func received(_ paths: [String]) {
        for path in paths {
            let url = URL(filePath: path)
            guard !Self.isIgnored(url) else { continue }

            pending.insert(url.deletingLastPathComponent())
        }

        guard !pending.isEmpty else { return }

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
