import Foundation

public struct AgentRepositoryChanges: Identifiable, Sendable {

    public var id: String {
        root
    }

    public var name: String {
        URL(filePath: root).lastPathComponent
    }

    public let root: String
    public let changes: [GitChange]
    public let touchedOnly: [AgentTouchedFile]
    public let touchedAt: Date
    public let commits: [GitCommitChanges]

    let nodes: [GitTreeNode]

    public init(
        root: String,
        changes: [GitChange],
        touchedOnly: [AgentTouchedFile],
        touchedAt: Date,
        commits: [GitCommitChanges] = []
    ) {
        self.root = root
        self.changes = changes
        self.touchedOnly = touchedOnly
        self.touchedAt = touchedAt
        self.commits = commits

        var files: [String: GitFileStatus?] = [:]
        for commit in commits.reversed() {
            for change in commit.changes {
                files[change.path] = change.status
            }
        }

        for change in changes {
            files[change.path] = change.status
        }

        let base = root.hasSuffix("/") ? root : root + "/"
        for file in touchedOnly {
            let path = file.url.path(percentEncoded: false)
            guard path.hasPrefix(base) else { continue }

            files[String(path.dropFirst(base.count))] = .some(nil)
        }

        self.nodes = GitTreeBuilder.build(files: files, at: URL(filePath: root))
    }
}
