import Foundation

struct LanguageProfile: Sendable {

    static let plain = LanguageProfile(
        lineComment: nil,
        blockOpen: nil,
        blockClose: nil,
        nestsBlockComments: false,
        quotes: ["\"", "'"],
        keywords: []
    )

    private static let cLike = LanguageProfile(
        lineComment: "//",
        blockOpen: "/*",
        blockClose: "*/",
        nestsBlockComments: false,
        quotes: ["\"", "'"],
        keywords: [
            "if", "else", "for", "while", "do", "switch", "case", "default", "break", "continue",
            "return", "struct", "enum", "union", "typedef", "const", "static", "void", "int",
            "char", "float", "double", "long", "short", "unsigned", "signed", "sizeof", "class",
            "public", "private", "protected", "new", "delete", "template", "namespace", "using",
            "this", "true", "false", "null", "nullptr", "try", "catch", "throw"
        ]
    )

    private static let swift = LanguageProfile(
        lineComment: "//",
        blockOpen: "/*",
        blockClose: "*/",
        nestsBlockComments: true,
        quotes: ["\""],
        keywords: [
            "func", "let", "var", "if", "else", "guard", "for", "while", "repeat", "switch",
            "case", "default", "break", "continue", "return", "struct", "class", "enum",
            "protocol", "extension", "actor", "init", "deinit", "self", "Self", "super",
            "import", "typealias", "associatedtype", "where", "in", "is", "as", "try", "throw",
            "throws", "rethrows", "catch", "defer", "async", "await", "public", "private",
            "fileprivate", "internal", "open", "static", "final", "lazy", "weak", "unowned",
            "mutating", "nonisolated", "override", "some", "any", "inout", "true", "false", "nil"
        ]
    )

    private static let javascript = LanguageProfile(
        lineComment: "//",
        blockOpen: "/*",
        blockClose: "*/",
        nestsBlockComments: false,
        quotes: ["\"", "'", "`"],
        keywords: [
            "function", "const", "let", "var", "if", "else", "for", "while", "do", "switch",
            "case", "default", "break", "continue", "return", "class", "extends", "new", "this",
            "super", "import", "export", "from", "as", "async", "await", "try", "catch",
            "finally", "throw", "typeof", "instanceof", "in", "of", "delete", "yield",
            "interface", "type", "enum", "implements", "public", "private", "readonly", "static",
            "true", "false", "null", "undefined", "void"
        ]
    )

    private static let python = LanguageProfile(
        lineComment: "#",
        blockOpen: nil,
        blockClose: nil,
        nestsBlockComments: false,
        quotes: ["\"", "'"],
        keywords: [
            "def", "class", "if", "elif", "else", "for", "while", "break", "continue", "return",
            "import", "from", "as", "try", "except", "finally", "raise", "with", "lambda",
            "yield", "global", "nonlocal", "pass", "assert", "del", "in", "is", "not", "and",
            "or", "async", "await", "True", "False", "None", "self"
        ]
    )

    private static let go = LanguageProfile(
        lineComment: "//",
        blockOpen: "/*",
        blockClose: "*/",
        nestsBlockComments: false,
        quotes: ["\"", "`", "'"],
        keywords: [
            "func", "var", "const", "type", "struct", "interface", "map", "chan", "package",
            "import", "if", "else", "for", "range", "switch", "case", "default", "break",
            "continue", "return", "go", "defer", "select", "fallthrough", "nil", "true", "false"
        ]
    )

    private static let rust = LanguageProfile(
        lineComment: "//",
        blockOpen: "/*",
        blockClose: "*/",
        nestsBlockComments: true,
        quotes: ["\"", "'"],
        keywords: [
            "fn", "let", "mut", "const", "static", "struct", "enum", "trait", "impl", "for",
            "while", "loop", "if", "else", "match", "break", "continue", "return", "use", "mod",
            "pub", "crate", "self", "Self", "super", "where", "as", "dyn", "ref", "move",
            "async", "await", "unsafe", "type", "true", "false"
        ]
    )

    private static let zig = LanguageProfile(
        lineComment: "//",
        blockOpen: nil,
        blockClose: nil,
        nestsBlockComments: false,
        quotes: ["\""],
        keywords: [
            "const", "var", "fn", "pub", "struct", "enum", "union", "error", "if", "else",
            "while", "for", "switch", "break", "continue", "return", "defer", "errdefer", "try",
            "catch", "orelse", "comptime", "inline", "export", "extern", "test", "usingnamespace",
            "align", "anytype", "null", "undefined", "true", "false"
        ]
    )

    private static let shell = LanguageProfile(
        lineComment: "#",
        blockOpen: nil,
        blockClose: nil,
        nestsBlockComments: false,
        quotes: ["\"", "'"],
        keywords: [
            "if", "then", "else", "elif", "fi", "for", "in", "do", "done", "while", "until",
            "case", "esac", "function", "return", "local", "export", "source", "echo", "cd",
            "set", "unset", "readonly", "shift", "exit"
        ]
    )

    private static let json = LanguageProfile(
        lineComment: nil,
        blockOpen: nil,
        blockClose: nil,
        nestsBlockComments: false,
        quotes: ["\""],
        keywords: ["true", "false", "null"]
    )

    private static let yaml = LanguageProfile(
        lineComment: "#",
        blockOpen: nil,
        blockClose: nil,
        nestsBlockComments: false,
        quotes: ["\"", "'"],
        keywords: ["true", "false", "null", "yes", "no", "on", "off"]
    )

    private static let table: [String: LanguageProfile] = [
        "swift": swift,
        "c": cLike, "h": cLike, "cpp": cLike, "cc": cLike, "hpp": cLike,
        "m": cLike, "mm": cLike, "objc": cLike, "java": cLike, "kotlin": cLike, "kt": cLike,
        "js": javascript, "javascript": javascript, "jsx": javascript,
        "ts": javascript, "typescript": javascript, "tsx": javascript,
        "py": python, "python": python,
        "go": go, "golang": go,
        "rs": rust, "rust": rust,
        "zig": zig,
        "sh": shell, "bash": shell, "zsh": shell, "shell": shell,
        "json": json,
        "yml": yaml, "yaml": yaml
    ]

    let lineComment: String?
    let blockOpen: String?
    let blockClose: String?
    let nestsBlockComments: Bool
    let quotes: Set<Character>
    let keywords: Set<String>

    static func named(_ language: String?) -> LanguageProfile {
        guard let language else { return plain }

        return table[language.lowercased()] ?? plain
    }
}
