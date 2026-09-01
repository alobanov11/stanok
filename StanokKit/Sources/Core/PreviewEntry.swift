import Foundation

enum PreviewEntry: Identifiable, Sendable {

    case file(FilePreview)
    case web(WebPreview)
    case review(ReviewKind)

    var id: String {
        switch self {
        case let .file(preview): "file:" + preview.url.absoluteString
        case let .web(preview): "web:" + preview.url.absoluteString
        case let .review(kind): "review:" + kind.key
        }
    }

    var name: String {
        switch self {
        case let .file(preview): preview.name
        case let .web(preview): preview.name
        case let .review(kind): kind.title
        }
    }
}
