import AppKit

struct PreviewDocument {

    static let sourceLine = NSAttributedString.Key("stanok.sourceLine")

    static var empty: PreviewDocument {
        PreviewDocument(text: NSAttributedString(), revision: "")
    }

    let text: NSAttributedString
    let revision: String
}
