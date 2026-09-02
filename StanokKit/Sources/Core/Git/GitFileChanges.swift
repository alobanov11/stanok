import Foundation

struct GitFileChanges: Sendable, Equatable {

    static let none = GitFileChanges(kinds: [:], removed: [:])

    let kinds: [Int: LineChange]
    let removed: [Int: [String]]
    let digest: Int

    init(kinds: [Int: LineChange], removed: [Int: [String]]) {
        self.kinds = kinds
        self.removed = removed
        self.digest = Self.digest(kinds: kinds, removed: removed)
    }

    // Почему: одинаковые счётчики бывают у разных диффов, сравнивать нужно содержимое
    static func digest(kinds: [Int: LineChange], removed: [Int: [String]]) -> Int {
        var hasher = Hasher()

        for line in kinds.keys.sorted() {
            hasher.combine(line)
            hasher.combine(kinds[line])
        }

        for line in removed.keys.sorted() {
            hasher.combine(line)
            hasher.combine(removed[line])
        }

        return hasher.finalize()
    }
}
