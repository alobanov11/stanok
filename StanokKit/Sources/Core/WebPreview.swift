import Foundation

struct WebPreview: Identifiable, Sendable {

    var id: URL { url }

    var name: String { url.host ?? url.absoluteString }

    let url: URL
}
