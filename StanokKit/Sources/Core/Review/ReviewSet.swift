import Foundation

public struct ReviewSet: Sendable, Equatable {

    public var id: String {
        title + "#" + files.map(\.path).joined(separator: "|")
    }

    public var name: String {
        files.count == 1 ? title + " — 1 файл" : title + " — \(files.count) файлов"
    }

    public let title: String
    public let files: [ReviewFile]

    public init(title: String, files: [ReviewFile]) {
        self.title = title
        self.files = files
    }
}
