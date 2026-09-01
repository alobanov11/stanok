import Foundation

@MainActor
@Observable
final class PreviewNavigators {

    private var byRoot: [UUID: PreviewNavigator] = [:]

    private let orphan = PreviewNavigator()

    func navigator(for root: UUID?) -> PreviewNavigator {
        guard let root else { return orphan }

        if let existing = byRoot[root] { return existing }

        let navigator = PreviewNavigator()
        byRoot[root] = navigator
        return navigator
    }

    func inherit(_ root: UUID, from previous: UUID) {
        guard let navigator = byRoot.removeValue(forKey: previous) else { return }

        byRoot[root] = navigator
    }

    func prune(roots: Set<UUID>) {
        byRoot = byRoot.filter { roots.contains($0.key) }
    }
}
