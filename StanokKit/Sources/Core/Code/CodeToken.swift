import Foundation

struct CodeToken: Sendable {

    enum Kind: Sendable, Equatable, Hashable {

        case plain
        case comment
        case string
        case number
        case keyword
    }

    let text: String
    let kind: Kind
}
