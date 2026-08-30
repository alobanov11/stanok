import Foundation

enum PreviewEntry: Identifiable, Sendable {

    case file(FilePreview)
    case web(WebPreview)

    var id: String {
        switch self {
        case let .file(preview): "file:" + preview.url.absoluteString
        case let .web(preview): "web:" + preview.url.absoluteString
        }
    }

    var name: String {
        switch self {
        case let .file(preview): preview.name
        case let .web(preview): preview.name
        }
    }
}
