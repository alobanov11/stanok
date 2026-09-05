import AppKit

struct PreviewDocument: @unchecked Sendable {

    enum Key {

        static let sourceLine = NSAttributedString.Key("stanok.sourceLine")
        static let gap = NSAttributedString.Key("stanok.gap")
        static let note = NSAttributedString.Key("stanok.note")
    }

    static var empty: PreviewDocument {
        PreviewDocument(text: NSAttributedString(), lines: [], revision: "")
    }

    let text: NSAttributedString
    let lines: [Int]
    let revision: String
}
