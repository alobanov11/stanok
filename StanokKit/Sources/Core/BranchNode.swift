import Foundation

@MainActor
@Observable
public final class BranchNode: Identifiable {

    public var visibleDescendants: [BranchNode] {
        var result: [BranchNode] = []
        appendVisibleDescendants(to: &result)
        return result
    }

    public nonisolated let id: String

    public let name: String

    public let isFolder: Bool

    public let depth: Int

    public let ref: GitBranchRef?

    public var isExpanded: Bool

    public let children: [BranchNode]

    public init(
        id: String,
        name: String,
        isFolder: Bool,
        depth: Int,
        ref: GitBranchRef? = nil,
        isExpanded: Bool = false,
        children: [BranchNode] = []
    ) {
        self.id = id
        self.name = name
        self.isFolder = isFolder
        self.depth = depth
        self.ref = ref
        self.isExpanded = isExpanded
        self.children = children
    }

    public func toggle() {
        guard isFolder else { return }

        isExpanded.toggle()
    }

    private func appendVisibleDescendants(to result: inout [BranchNode]) {
        guard isExpanded else { return }

        for child in children {
            result.append(child)
            child.appendVisibleDescendants(to: &result)
        }
    }
}
