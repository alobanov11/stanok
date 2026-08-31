import Foundation

struct FilePreview: Identifiable, Sendable {

    enum Content: Sendable {

        case markdown([MarkdownBlock])
        case code([[CodeToken]])
        case unreadable
        case tooLarge
        case failed(String)
    }

    var id: URL { url }
    var name: String { url.lastPathComponent }
    let url: URL
    let content: Content
    let size: Int64
    let kind: String
    let modified: Date?
    let isTruncated: Bool
    var changes: [Int: LineChange] = [:]
}
