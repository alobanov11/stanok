import Foundation

enum CodeFolding {

    static func folds(for lines: [[CodeToken]]) -> [CodeFold] {
        let indents = lines.map(indent)
        var open: [(indent: Int, header: Int)] = []
        var folds: [CodeFold] = []
        var lastFilled = -1

        for (index, indent) in indents.enumerated() {
            guard let indent else { continue }

            while let top = open.last, indent <= top.indent {
                append(top, end: lastFilled, depth: open.count - 1, into: &folds)
                open.removeLast()
            }

            open.append((indent, index))
            lastFilled = index
        }

        while let top = open.last {
            append(top, end: lastFilled, depth: open.count - 1, into: &folds)
            open.removeLast()
        }

        return folds.sorted { $0.header < $1.header }
    }

    static func indent(_ tokens: [CodeToken]) -> Int? {
        let text = tokens.map(\.text).joined()
        guard !text.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }

        return text.prefix { $0 == " " || $0 == "\t" }.count
    }

    private static func append(
        _ open: (indent: Int, header: Int),
        end: Int,
        depth: Int,
        into folds: inout [CodeFold]
    ) {
        guard end > open.header else { return }

        folds.append(CodeFold(header: open.header, end: end, depth: depth))
    }
}
