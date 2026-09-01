import AppKit

struct PreviewDocument: @unchecked Sendable {

    static let sourceLine = NSAttributedString.Key("stanok.sourceLine")
    static let gap = NSAttributedString.Key("stanok.gap")

    static var empty: PreviewDocument {
        PreviewDocument(text: NSAttributedString(), lines: [], revision: "")
    }

    let text: NSAttributedString
    let lines: [Int]
    let revision: String
}
