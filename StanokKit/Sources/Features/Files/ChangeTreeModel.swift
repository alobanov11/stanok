import Foundation

@MainActor
@Observable
final class ChangeTreeModel {

    var visible: [GitTreeNode] {
        var result: [GitTreeNode] = []
        for node in nodes {
            append(node, into: &result)
        }
        return result
    }

    private(set) var nodes: [GitTreeNode] = []

    private var collapsed: Set<String> = []

    func apply(_ snapshot: GitSnapshot?) {
        guard let snapshot else {
            nodes = []
            return
        }

        nodes = GitTreeBuilder.build(from: snapshot, at: URL(filePath: snapshot.root))
    }

    func isExpanded(_ node: GitTreeNode) -> Bool {
        !collapsed.contains(node.relativePath)
    }

    func toggle(_ node: GitTreeNode) {
        guard node.isDirectory else { return }

        if collapsed.contains(node.relativePath) {
            collapsed.remove(node.relativePath)
        } else {
            collapsed.insert(node.relativePath)
        }
    }

    private func append(_ node: GitTreeNode, into result: inout [GitTreeNode]) {
        result.append(node)
        guard node.isDirectory, isExpanded(node) else { return }

        for child in node.children {
            append(child, into: &result)
        }
    }
}
