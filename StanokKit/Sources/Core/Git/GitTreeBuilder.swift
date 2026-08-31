import Foundation

enum GitTreeBuilder {

    private struct Entry {

        let isDirectory: Bool
        let status: GitFileStatus?
    }

    static func build(from snapshot: GitSnapshot, at root: URL) -> [GitTreeNode] {
        var entries: [String: Entry] = [:]

        for path in snapshot.dirtyDirectories {
            entries[path] = Entry(isDirectory: true, status: .modified)
        }

        for change in snapshot.changes {
            entries[change.path] = Entry(isDirectory: false, status: change.status)
        }

        var childrenByParent: [String: [String]] = [:]
        for path in entries.keys {
            childrenByParent[parent(of: path), default: []].append(path)
        }

        func makeNode(_ path: String) -> GitTreeNode {
            let entry = entries[path] ?? Entry(isDirectory: false, status: nil)
            let components = path.split(separator: "/")
            let childPaths = (childrenByParent[path] ?? [])
                .sorted { precedes($0, $1, entries: entries) }

            return GitTreeNode(
                name: String(components.last ?? Substring(path)),
                url: root.appending(path: path),
                isDirectory: entry.isDirectory,
                depth: components.count,
                relativePath: path,
                status: entry.status,
                children: entry.isDirectory ? childPaths.map(makeNode) : []
            )
        }

        return (childrenByParent[""] ?? [])
            .sorted { precedes($0, $1, entries: entries) }
            .map(makeNode)
    }

    private static func parent(of path: String) -> String {
        var components = path.split(separator: "/")
        guard components.count > 1 else { return "" }

        components.removeLast()
        return components.joined(separator: "/")
    }

    private static func precedes(_ lhs: String, _ rhs: String, entries: [String: Entry]) -> Bool {
        let leftIsDirectory = entries[lhs]?.isDirectory ?? false
        let rightIsDirectory = entries[rhs]?.isDirectory ?? false
        if leftIsDirectory != rightIsDirectory { return leftIsDirectory }

        return lhs.localizedStandardCompare(rhs) == .orderedAscending
    }
}
