import Foundation

public struct ReviewFile: Identifiable, Sendable, Equatable {

    public var id: URL {
        url
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

    public init(
        url: URL,
        path: String,
        status: GitFileStatus?,
        root: String,
        groupName: String? = nil
    ) {
        self.url = url
        self.path = path
        self.status = status
        self.root = root
        self.groupName = groupName
    }
}
