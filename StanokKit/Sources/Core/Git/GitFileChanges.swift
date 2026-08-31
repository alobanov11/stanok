import Foundation

struct GitFileChanges: Sendable, Equatable {

    static let none = GitFileChanges(kinds: [:], removed: [:])

    let kinds: [Int: LineChange]
    let removed: [Int: [String]]
}
