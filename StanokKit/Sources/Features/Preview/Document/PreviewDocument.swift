import AppKit

struct PreviewDocument {

    static let sourceLine = NSAttributedString.Key("stanok.sourceLine")

    static var empty: PreviewDocument {
        PreviewDocument(text: NSAttributedString(), lines: [], folds: .empty)
    }

    var isEmpty: Bool {
        text.length == 0
    }

    let text: NSAttributedString
    let lines: [Int]
    let folds: CodeFoldMap
}
