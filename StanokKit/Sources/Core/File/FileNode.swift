import Foundation

@MainActor
@Observable
final class FileNode: Identifiable {

    nonisolated var id: URL {
        url
    }

    var name: String {
        url.lastPathComponent
    }

    var visibleDescendants: [FileNode] {
        var result: [FileNode] = []
        appendVisibleDescendants(to: &result)
        return result
    }

    var isExpanded = false

    let url: URL
    let isDirectory: Bool
    let depth: Int
    let relativePath: String

    private(set) var children: [FileNode]?

    init(url: URL, isDirectory: Bool, depth: Int, relativePath: String) {
        self.url = url
        self.isDirectory = isDirectory
        self.depth = depth
        self.relativePath = relativePath
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
        let normalized = target.standardizedFileURL
        if url.standardizedFileURL == normalized { return self }

        guard let children, contains(normalized) else { return nil }

        for child in children {
            if let found = child.node(at: normalized) { return found }
        }

        return nil
    }

    func reveal(_ target: URL) -> FileNode? {
        let normalized = target.standardizedFileURL
        if url.standardizedFileURL == normalized { return self }

        guard isDirectory, contains(normalized) else { return nil }

        expand()
        guard let children else { return nil }

        for child in children {
            if let found = child.reveal(normalized) { return found }
        }

        return nil
    }

    func reload() {
        guard let children else { return }

        var existing: [URL: FileNode] = [:]
        for child in children {
            existing[child.url] = child
        }

        guard let rebuilt = rebuild(reusing: existing) else { return }
        guard rebuilt.map(\.url) != children.map(\.url) else { return }

        self.children = rebuilt
    }
}

private extension FileNode {

    static func precedes(_ lhs: FileNode, _ rhs: FileNode) -> Bool {
        if lhs.isDirectory != rhs.isDirectory { return lhs.isDirectory }

        return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
    }

    static func isDirectory(_ url: URL) -> Bool {
        (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
    }

    func appendVisibleDescendants(to result: inout [FileNode]) {
        guard isExpanded, let children else { return }

        for child in children {
            result.append(child)
            child.appendVisibleDescendants(to: &result)
        }
    }

    func loadIfNeeded() {
        guard isExpanded, children == nil else { return }

        if let rebuilt = rebuild(reusing: [:]) {
            children = rebuilt
        }
    }

    func childRelativePath(_ name: String) -> String {
        relativePath.isEmpty ? name : "\(relativePath)/\(name)"
    }

    func contains(_ target: URL) -> Bool {
        let base = url.standardizedFileURL.path(percentEncoded: false)
        let path = target.path(percentEncoded: false)

        return path.hasPrefix(base.hasSuffix("/") ? base : base + "/")
    }

    func rebuild(reusing existing: [URL: FileNode]) -> [FileNode]? {
        let contents: [URL]
        do {
            contents = try FileManager.default.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: [.isDirectoryKey]
            )
        } catch {
            let path = url.path(percentEncoded: false)
            let reason = error.localizedDescription
            Log.terminal.error("cannot list \(path): \(reason)")
            return nil
        }

        return contents
            .filter { child in
                guard Self.isDirectory(child) else { return true }

                return !IgnoredPaths.contains(
                    relativePath: childRelativePath(child.lastPathComponent)
                ) && !IgnoredPaths.isExcludedHomeChild(child)
            }
            .map { child in
                existing[child] ?? FileNode(
                    url: child,
                    isDirectory: Self.isDirectory(child),
                    depth: depth + 1,
                    relativePath: childRelativePath(child.lastPathComponent)
                )
            }
            .sorted(by: Self.precedes)
    }
}
