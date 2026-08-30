import Foundation

@MainActor
@Observable
final class FileNode: Identifiable {

    nonisolated var id: URL { url }

    var name: String { url.lastPathComponent }

    var visibleDescendants: [FileNode] {
        guard isExpanded, let children else { return [] }

        return children.flatMap { [$0] + $0.visibleDescendants }
    }

    let url: URL

    let isDirectory: Bool

    let depth: Int

    var isExpanded = false

    private(set) var children: [FileNode]?

    init(url: URL, isDirectory: Bool, depth: Int) {
        self.url = url
        self.isDirectory = isDirectory
        self.depth = depth
    }

    private static func precedes(_ lhs: FileNode, _ rhs: FileNode) -> Bool {
        if lhs.isDirectory != rhs.isDirectory { return lhs.isDirectory }

        return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
    }

    private static func isDirectory(_ url: URL) -> Bool {
        (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
    }

    func toggle() {
        guard isDirectory else { return }

        isExpanded.toggle()
        loadIfNeeded()
    }

    func expand() {
        guard isDirectory else { return }

        isExpanded = true
        loadIfNeeded()
    }

    func node(at target: URL) -> FileNode? {
        if url == target { return self }

        guard
            let children,
            target.path(percentEncoded: false).hasPrefix(url.path(percentEncoded: false))
        else { return nil }

        for child in children {
            if let found = child.node(at: target) { return found }
        }

        return nil
    }

    func reload() {
        guard let children else { return }

        var existing: [URL: FileNode] = [:]
        for child in children {
            existing[child.url] = child
        }

        self.children = rebuild(reusing: existing)
    }

    private func loadIfNeeded() {
        guard isExpanded, children == nil else { return }

        children = rebuild(reusing: [:])
    }

    private func rebuild(reusing existing: [URL: FileNode]) -> [FileNode] {
        let contents = (try? FileManager.default.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey]
        )) ?? []

        return contents
            .filter { $0.lastPathComponent != ".git" }
            .map { child in
                existing[child] ?? FileNode(
                    url: child,
                    isDirectory: Self.isDirectory(child),
                    depth: depth + 1
                )
            }
            .sorted(by: Self.precedes)
    }
}
