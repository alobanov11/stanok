import SwiftUI

public enum GitFileStatus: Equatable, Sendable {

    case modified
    case added
    case deleted
    case renamed
    case copied
    case typeChanged
    case untracked
    case conflicted

    public var letter: String {
        switch self {
        case .modified: "M"
        case .added: "A"
        case .deleted: "D"
        case .renamed: "R"
        case .copied: "C"
        case .typeChanged: "T"
        case .untracked: "?"
        case .conflicted: "U"
        }
    }

    public var color: Color {
        switch self {
        case .modified: .yellow
        case .added: .green
        case .deleted: .red
        case .renamed: .blue
        case .copied: .purple
        case .typeChanged: .orange
        case .untracked: .gray
        case .conflicted: .red
        }
    }
}
