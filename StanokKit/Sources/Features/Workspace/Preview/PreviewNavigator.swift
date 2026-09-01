import SwiftUI

@MainActor
@Observable
final class PreviewNavigator {

    private static let transitionDuration = 0.18
    private static let maxStackSize = 20

    var current: PreviewEntry? {
        stack.last
    }

    var previousName: String? {
        guard stack.count > 1 else { return nil }

        return stack[stack.count - 2].name
    }

    private(set) var stack: [PreviewEntry] = []

    private var token = UUID()
    private var loadTask: Task<FilePreview, Never>?

    func openFile(_ url: URL) async {
        await load(url, replacing: false)
    }

    func reloadFile(_ url: URL) async {
        await load(url, replacing: true)
    }

    func openReview(_ kind: ReviewKind) {
        token = UUID()
        loadTask?.cancel()
        loadTask = nil

        if case .review = stack.last {
            withAnimation(.smooth(duration: Self.transitionDuration)) {
                stack[stack.count - 1] = .review(kind)
            }
            return
        }

        push(.review(kind))
    }

    func openWeb(_ url: URL) {
        token = UUID()
        loadTask?.cancel()
        loadTask = nil
        push(.web(WebPreview(url: url)))
    }

    func pop() {
        token = UUID()
        loadTask?.cancel()
        loadTask = nil

        guard !stack.isEmpty else { return }

        withAnimation(.smooth(duration: Self.transitionDuration)) { _ = stack.popLast() }
    }

    func clear() {
        token = UUID()
        loadTask?.cancel()
        loadTask = nil

        guard !stack.isEmpty else { return }

        withAnimation(.smooth(duration: Self.transitionDuration)) { stack = [] }
    }

    private func load(_ url: URL, replacing: Bool) async {
        let generation = UUID()
        token = generation
        loadTask?.cancel()

        let task = Task { await FilePreviewLoader.load(url) }
        loadTask = task

        let loaded = await task.value
        guard token == generation else { return }

        if replacing, !stack.isEmpty {
            stack[stack.count - 1] = .file(loaded)
        } else {
            push(.file(loaded))
        }
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
