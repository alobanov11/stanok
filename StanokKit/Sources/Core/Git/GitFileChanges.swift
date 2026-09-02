import Foundation

struct GitFileChanges: Sendable, Equatable {

    static let none = GitFileChanges(kinds: [:], removed: [:])

    // Почему: одинаковые счётчики бывают у разных диффов, сравнивать нужно содержимое
    var digest: Int {
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

    let kinds: [Int: LineChange]
    let removed: [Int: [String]]
}
