import Foundation

struct FileStamp: Equatable, Sendable {

    private static let keys: Set<URLResourceKey> = [.fileSizeKey, .contentModificationDateKey]

    let size: Int64
    let modified: Date?

    init(size: Int64, modified: Date?) {
        self.size = size
        self.modified = modified
    }

    init?(of url: URL) {
        guard let values = try? url.resourceValues(forKeys: Self.keys) else { return nil }

        self.init(size: Int64(values.fileSize ?? 0), modified: values.contentModificationDate)
    }
}
