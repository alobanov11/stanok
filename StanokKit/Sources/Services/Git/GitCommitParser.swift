import Foundation

enum GitCommitParser {

    static func parse(_ data: Data) -> [GitChange] {
        let fields = data.split(separator: UInt8(0))
            .compactMap { String(data: Data($0), encoding: .utf8) }
            .filter { !$0.isEmpty }

        var changes: [GitChange] = []
        var index = fields.startIndex

        while index < fields.endIndex {
            let letter = fields[index]
            index = fields.index(after: index)
            guard index < fields.endIndex else { break }

            let first = fields[index]
            index = fields.index(after: index)

            // Почему: переименование и копирование приносят два пути вместо одного
            let renamed = letter.hasPrefix("R") || letter.hasPrefix("C")
            var path = first
            var original: String?

            if renamed, index < fields.endIndex {
                original = first
                path = fields[index]
                index = fields.index(after: index)
            }

            changes.append(GitChange(
                path: path,
                originalPath: original,
                status: status(for: letter)
            ))
        }

        return changes.sorted { $0.path < $1.path }
    }

    static func status(for letter: String) -> GitFileStatus {
        switch letter.first {
        case "A": .added
        case "D": .deleted
        case "R": .renamed
        case "C": .copied
        case "T": .typeChanged
        default: .modified
        }
    }
}
