import Foundation

enum CodeHighlighter {

    private enum State {

        case normal
        case blockComment
        case string(Character)
    }

    private struct Scanner {

        let code: [Character]

        let profile: LanguageProfile

        private var lines: [[CodeToken]] = []

        private var line: [CodeToken] = []

        private var text = ""

        private var kind = CodeToken.Kind.plain

        private var state = State.normal

        private var depth = 0

        private var index = 0

        init(code: [Character], profile: LanguageProfile) {
            self.code = code
            self.profile = profile
        }

        private static func isIdentifier(_ character: Character) -> Bool {
            character.isLetter || character.isNumber || character == "_" || character == "$"
        }

        private static func isNumber(_ character: Character) -> Bool {
            character.isHexDigit || character == "." || character == "_"
                || character == "x" || character == "o" || character == "b"
        }

        mutating func run() -> [[CodeToken]] {
            while index < code.count {
                switch state {
                case .blockComment: scanBlockComment()
                case let .string(quote): scanString(quote)
                case .normal: scanNormal()
                }
            }

            newline()
            return lines
        }

        private func matches(_ token: String?) -> Bool {
            guard let token, !token.isEmpty, index + token.count <= code.count else { return false }

            return String(code[index..<index + token.count]) == token
        }

        private mutating func flush() {
            guard !text.isEmpty else { return }

            line.append(CodeToken(text: text, kind: kind))
            text = ""
        }

        private mutating func newline() {
            flush()
            lines.append(line)
            line = []
        }

        private mutating func emit(_ character: Character, _ next: CodeToken.Kind) {
            if character.isNewline {
                newline()
                return
            }

            if next != kind {
                flush()
                kind = next
            }

            text.append(character)
        }

        private mutating func take(_ token: String, _ next: CodeToken.Kind) {
            for character in token {
                emit(character, next)
            }
            index += token.count
        }

        private mutating func scanBlockComment() {
            if let open = profile.blockOpen, profile.nestsBlockComments, matches(open) {
                depth += 1
                take(open, .comment)
                return
            }

            if let close = profile.blockClose, matches(close) {
                take(close, .comment)
                depth -= 1
                if depth <= 0 { state = .normal }
                return
            }

            emit(code[index], .comment)
            index += 1
        }

        private mutating func scanString(_ quote: Character) {
            let character = code[index]

            if character == "\\", index + 1 < code.count {
                emit(character, .string)
                emit(code[index + 1], .string)
                index += 2
                return
            }

            emit(character, .string)
            index += 1
            if character == quote { state = .normal }
        }

        private mutating func scanNormal() {
            let character = code[index]

            if matches(profile.lineComment) {
                while index < code.count, !code[index].isNewline {
                    emit(code[index], .comment)
                    index += 1
                }
                return
            }

            if let open = profile.blockOpen, matches(open) {
                depth = 1
                take(open, .comment)
                state = .blockComment
                return
            }

            if profile.quotes.contains(character) {
                emit(character, .string)
                index += 1
                state = .string(character)
                return
            }

            if character.isNumber {
                while index < code.count, Self.isNumber(code[index]) {
                    emit(code[index], .number)
                    index += 1
                }
                return
            }

            if character.isLetter || character == "_" {
                scanWord()
                return
            }

            emit(character, .plain)
            index += 1
        }

        private mutating func scanWord() {
            var word = ""
            while index < code.count, Self.isIdentifier(code[index]) {
                word.append(code[index])
                index += 1
            }

            let next: CodeToken.Kind = profile.keywords.contains(word) ? .keyword : .plain
            for character in word {
                emit(character, next)
            }
        }
    }

    static func lines(_ code: String, language: String?) -> [[CodeToken]] {
        var scanner = Scanner(code: Array(code), profile: .named(language))
        return scanner.run()
    }
}
