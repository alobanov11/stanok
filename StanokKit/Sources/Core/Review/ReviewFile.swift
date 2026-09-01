import Foundation

public struct ReviewFile: Identifiable, Sendable, Equatable {

    public var id: String {
        source.key + "|" + url.path(percentEncoded: false)
    }

    public var name: String {
        url.lastPathComponent
    }

    public var isReadable: Bool {
        status != .deleted
    }

    public let url: URL
    public let path: String
    public let status: GitFileStatus?
    public let root: String
    public let groupName: String?
    public let source: ReviewSource

    public init(
        url: URL,
        path: String,
        status: GitFileStatus?,
        root: String,
        groupName: String? = nil,
        source: ReviewSource = .worktree
    ) {
        self.url = url
        self.path = path
        self.status = status
        self.root = root
        self.groupName = groupName
        self.source = source
    }
}
