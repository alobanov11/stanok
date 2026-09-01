import Foundation

public struct GitSnapshot: Equatable, Sendable {

    public let branch: String?
    public let isDetached: Bool
    public let root: String
    public let gitDirectory: String
    public let commonDirectory: String
    public let added: Int
    public let removed: Int
    public let changes: [GitChange]
    public let tracking: GitTracking
    public let byPath: [String: GitFileStatus]
    public let dirtyDirectories: Set<String>

    public init(
        branch: String?,
        isDetached: Bool,
        root: String,
        gitDirectory: String,
        commonDirectory: String? = nil,
        added: Int,
        removed: Int,
        changes: [GitChange],
        tracking: GitTracking = .none
    ) {
        self.branch = branch
        self.isDetached = isDetached
        self.root = root
        self.gitDirectory = gitDirectory
        self.commonDirectory = commonDirectory ?? gitDirectory
        self.added = added
        self.removed = removed
        self.changes = changes
        self.tracking = tracking

        var byPath: [String: GitFileStatus] = [:]
        var dirtyDirectories: Set<String> = []

        for change in changes {
            byPath[change.path] = change.status
            GitSnapshot.insertAncestors(of: change.path, into: &dirtyDirectories)
        }

        self.byPath = byPath
        self.dirtyDirectories = dirtyDirectories
    }

    private static func insertAncestors(of path: String, into directories: inout Set<String>) {
        var components = path.split(separator: "/")
        guard components.count > 1 else { return }

        components.removeLast()

        var prefix = ""
        for component in components {
            prefix = prefix.isEmpty ? String(component) : "\(prefix)/\(component)"
            directories.insert(prefix)
        }
    }
}
