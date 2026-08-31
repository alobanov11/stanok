import Foundation

enum CodeFolding {

    static func folds(for lines: [[CodeToken]]) -> [CodeFold] {
        let braced = braces(in: lines)

        return braced.isEmpty ? indentation(in: lines) : braced
    }

    static func indent(_ tokens: [CodeToken]) -> Int? {
        let text = tokens.map(\.text).joined()
        guard !text.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }

        return text.prefix { $0 == " " || $0 == "\t" }.count
    }
}

private extension CodeFolding {

    static func braces(in lines: [[CodeToken]]) -> [CodeFold] {
        var open: [(line: Int, depth: Int)] = []
        var folds: [CodeFold] = []

        for (index, tokens) in lines.enumerated() {
            for token in tokens where token.kind == .plain {
                for character in token.text {
                    if character == "{" {
                        open.append((index, open.count))
                    } else if character == "}" {
                        guard let last = open.popLast() else { continue }
                        guard index > last.line else { continue }

                        folds.append(CodeFold(header: last.line, end: index - 1, depth: last.depth))
                    }
                }
            }
        }

        return folds.sorted { $0.header < $1.header }
    }

    static func indentation(in lines: [[CodeToken]]) -> [CodeFold] {
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

    static func append(
        _ open: (indent: Int, header: Int),
        end: Int,
        depth: Int,
        into folds: inout [CodeFold]
    ) {
        guard end > open.header else { return }

        folds.append(CodeFold(header: open.header, end: end, depth: depth))
    }
}
