import Foundation

enum GitCommitParser {

    static func commits(_ data: Data) -> [GitCommitChanges] {
        data.split(separator: 0x1E).compactMap { record in
            // Почему: заголовок склеен через \u{1f}, дальше идут поля name-status через \0
            let fields = Data(record).split(separator: 0)
                .map { String(decoding: $0, as: UTF8.self) }
                .filter { !$0.isEmpty }

            guard let header = fields.first else { return nil }

            let parts = header.split(separator: "\u{1f}", omittingEmptySubsequences: false)
            guard let sha = parts.first.map(String.init), !sha.isEmpty else { return nil }

            return GitCommitChanges(
                sha: sha,
                subject: parts.count > 1 ? String(parts[1]) : "",
                changes: changes(in: Array(fields.dropFirst()))
            )
        }
    }

    static func changes(in fields: [String]) -> [GitChange] {
        var changes: [GitChange] = []
        var index = fields.startIndex

        while index < fields.endIndex {
            // Почему: после заголовка git ставит перевод строки перед первой буквой статуса
            let letter = fields[index].trimmingCharacters(in: .whitespacesAndNewlines)
            index = fields.index(after: index)
            guard index < fields.endIndex else { break }

            let first = fields[index]
            index = fields.index(after: index)

            // Почему: переименование и копирование приносят два пути вместо одного
            let renamed = letter.hasPrefix("R") || letter.hasPrefix("C")
            var path = first
            var original: String?

            if renamed {
                guard index < fields.endIndex else { break }

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
