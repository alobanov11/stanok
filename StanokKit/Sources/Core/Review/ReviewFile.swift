import Foundation

public struct ReviewFile: Identifiable, Sendable, Equatable {

    public var id: URL {
        url
    }

    public var name: String {
        url.lastPathComponent
    }

    public let url: URL
    public let path: String
    public let status: GitFileStatus?
    public let group: String?

    public init(url: URL, path: String, status: GitFileStatus?, group: String? = nil) {
        self.url = url
        self.path = path
        self.status = status
        self.group = group
    }
}
