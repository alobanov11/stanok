import Foundation

@MainActor
public enum BranchTreeBuilder {

    private struct Entry {

        let components: [String]
        let ref: GitBranchRef
    }

    public static let branchesID = "Branches"
    public static let remotesID = "Remotes"

    public static func build(
        from refs: [GitBranchRef],
        reusing previous: BranchNode? = nil
    ) -> BranchNode {
        let localEntries = refs
            .filter { $0.kind == .local }
            .map { Entry(components: pathComponents(for: $0.displayName), ref: $0) }

        let remoteEntries = refs.compactMap { ref -> Entry? in
            guard ref.kind == .remote, let remoteName = ref.remoteName, !remoteName.isEmpty else {
                return nil
            }

            return Entry(components: [remoteName] + pathComponents(for: ref.displayName), ref: ref)
        }

        let branches = BranchNode(
            id: branchesID,
            name: branchesID,
            isFolder: true,
            depth: 1,
            isExpanded: true,
            children: buildLevel(localEntries, parentID: branchesID, depth: 2)
        )

        let remotes = BranchNode(
            id: remotesID,
            name: remotesID,
            isFolder: true,
            depth: 1,
            isExpanded: false,
            children: buildLevel(remoteEntries, parentID: remotesID, depth: 2)
        )

        let root = BranchNode(
            id: "",
            name: "",
            isFolder: true,
            depth: 0,
            isExpanded: true,
            children: [branches, remotes]
        )

        if let previous {
            reuseExpansion(in: root, from: previous)
        }

        return root
    }

    private static func pathComponents(for name: String) -> [String] {
        name.split(separator: "/").map(String.init)
    }

    private static func buildLevel(
        _ entries: [Entry],
        parentID: String,
        depth: Int
    ) -> [BranchNode] {
        var folderEntries: [String: [Entry]] = [:]
        var folderOrder: [String] = []
        var leafEntries: [Entry] = []

        for entry in entries {
            guard let head = entry.components.first else { continue }

            if entry.components.count == 1 {
                leafEntries.append(entry)
                continue
            }

            if folderEntries[head] == nil { folderOrder.append(head) }
            folderEntries[head, default: []].append(
                Entry(components: Array(entry.components.dropFirst()), ref: entry.ref)
            )
        }

        let folders = folderOrder
            .sorted { $0.localizedStandardCompare($1) == .orderedAscending }
            .map { name -> BranchNode in
                let id = "\(parentID)/\(name)"
                return BranchNode(
                    id: id,
                    name: name,
                    isFolder: true,
                    depth: depth,
                    children: buildLevel(folderEntries[name] ?? [], parentID: id, depth: depth + 1)
                )
            }

        let leaves = leafEntries
            .sorted { compareDisplayNames($0.ref, $1.ref) }
            .map { entry -> BranchNode in
                BranchNode(
                    id: "\(parentID)/\(entry.components[0])",
                    name: entry.components[0],
                    isFolder: false,
                    depth: depth,
                    ref: entry.ref
                )
            }

        return folders + leaves
    }

    private static func compareDisplayNames(_ lhs: GitBranchRef, _ rhs: GitBranchRef) -> Bool {
        lhs.displayName.localizedStandardCompare(rhs.displayName) == .orderedAscending
    }

    private static func reuseExpansion(in node: BranchNode, from previous: BranchNode) {
        guard node.isFolder, previous.isFolder else { return }

        node.isExpanded = previous.isExpanded

        let previousByID = Dictionary(uniqueKeysWithValues: previous.children.map { ($0.id, $0) })
        for child in node.children {
            guard let match = previousByID[child.id] else { continue }

            reuseExpansion(in: child, from: match)
        }
    }
}
