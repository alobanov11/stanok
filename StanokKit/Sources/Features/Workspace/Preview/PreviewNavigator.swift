import SwiftUI

@MainActor
@Observable
final class PreviewNavigator {

    private enum Activity {

        case opening
        case refreshing
    }

    private static let transitionDuration = 0.18
    private static let maxStackSize = 20

    var current: PreviewEntry? {
        stack.last
    }

    var previousName: String? {
        guard stack.count > 1 else { return nil }

        return stack[stack.count - 2].name
    }

    private var file: FilePreview? {
        guard case let .file(preview) = stack.last else { return nil }

        return preview
    }

    private(set) var stack: [PreviewEntry] = []

    private var activity: Activity?
    private var job: Task<Void, Never>?

    func openFile(_ url: URL) async {
        await load(url, replacing: false)
    }

    func reloadFile(_ url: URL) async {
        await load(url, replacing: true)
    }

    func refreshChanges() async {
        // Почему: идущее открытие само прочитает и свежий текст, и свежий дифф
        guard activity != .opening, let preview = file else { return }

        await run(.refreshing) { [self] in
            let changes = await GitLineChanges.load(for: preview.url)
            guard !Task.isCancelled else { return }

            // Почему: checkout и stash меняют сам файл, иначе рибоны лягут на прежний текст
            guard FileStamp(of: preview.url) == preview.stamp else {
                await reloadFile(preview.url)
                return
            }

            apply(changes, to: preview)
        }
    }

    func openReview(_ kind: ReviewKind) {
        cancel()

        if case .review = stack.last {
            withAnimation(.smooth(duration: Self.transitionDuration)) {
                stack[stack.count - 1] = .review(kind)
            }
            return
        }

        push(.review(kind))
    }

    func openWeb(_ url: URL) {
        cancel()
        push(.web(WebPreview(url: url)))
    }

    func pop() {
        cancel()

        guard !stack.isEmpty else { return }

        withAnimation(.smooth(duration: Self.transitionDuration)) { _ = stack.popLast() }
    }

    func clear() {
        cancel()

        guard !stack.isEmpty else { return }

        withAnimation(.smooth(duration: Self.transitionDuration)) { stack = [] }
    }

    private func cancel() {
        job?.cancel()
        job = nil
        activity = nil
    }

    private func run(_ kind: Activity, _ work: @escaping @MainActor () async -> Void) async {
        cancel()

        let task = Task { await work() }
        job = task
        activity = kind
        await task.value

        guard job == task else { return }

        cancel()
    }

    private func load(_ url: URL, replacing: Bool) async {
        await run(.opening) { [self] in
            let loaded = await FilePreviewLoader.load(url)
            guard !Task.isCancelled else { return }

            if replacing, !stack.isEmpty {
                stack[stack.count - 1] = .file(loaded)
            } else {
                push(.file(loaded))
            }
        }
    }

    private func apply(_ changes: GitFileChanges, to preview: FilePreview) {
        guard var latest = file, latest.url == preview.url, latest.changes != changes else { return }

        latest.changes = changes
        stack[stack.count - 1] = .file(latest)
    }

    private func push(_ entry: PreviewEntry) {
        withAnimation(.smooth(duration: Self.transitionDuration)) {
            stack.append(entry)

            if stack.count > Self.maxStackSize {
                stack.removeFirst(stack.count - Self.maxStackSize)
            }
        }
    }
}
