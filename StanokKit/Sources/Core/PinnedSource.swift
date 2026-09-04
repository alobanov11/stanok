import Foundation

public struct PinnedSource: Codable, Equatable, Identifiable, Sendable {

    public var name: String {
        url.lastPathComponent
    }

    public var url: URL {
        URL(filePath: path, directoryHint: .isDirectory)
    }

    public var path: String

    public let id: UUID

    public init(id: UUID = UUID(), path: String) {
        self.id = id
        self.path = path
    }
}
