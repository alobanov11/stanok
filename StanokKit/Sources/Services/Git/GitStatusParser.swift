import Foundation

public enum GitStatusParser {

    private enum FieldCount {

        static let ordinary = 8
        static let renameOrCopy = 9
        static let unmerged = 10
        static let untracked = 1
    }

    public static func parse(_ data: Data) -> [GitChange] {
        let chunks = data.split(separator: 0x00)
        var changes: [GitChange] = []
        var index = 0

        while index < chunks.count {
            let step = step(at: index, in: chunks)

            if let change = step.change { changes.append(change) }

            index += step.width
        }

        return changes
    }
}

private extension GitStatusParser {

    struct Step {

        let change: GitChange?
        let width: Int
    }

    static func step(at index: Int, in chunks: [Data.SubSequence]) -> Step {
        let text = decode(chunks[index])
        guard let prefix = text.first else { return Step(change: nil, width: 1) }

        switch prefix {
        case "1":
            return Step(change: parseOrdinary(text), width: 1)

        case "2":
            let originalPath = index + 1 < chunks.count ? decode(chunks[index + 1]) : nil

            return Step(change: parseRenameOrCopy(text, originalPath: originalPath), width: 2)

        case "u":
            return Step(change: parseUnmerged(text), width: 1)

        case "?":
            return Step(change: parseUntracked(text), width: 1)

        default:
            return Step(change: nil, width: 1)
        }
    }

    static func decode(_ chunk: Data.SubSequence) -> String {
        // swiftlint:disable:next optional_data_string_conversion
        String(decoding: chunk, as: UTF8.self)
    }

    static func splitFields(
        _ text: String,
        count: Int
    ) -> (fields: [Substring], path: String)? {
        let parts = text.split(separator: " ", maxSplits: count, omittingEmptySubsequences: false)
        guard parts.count == count + 1 else { return nil }

        return (Array(parts[0..<count]), String(parts[count]))
    }

    static func pair(_ xy: Substring) -> (x: Character?, y: Character?) {
        var iterator = xy.makeIterator()
        return (iterator.next(), iterator.next())
    }

    static func status(xy: Substring) -> GitFileStatus {
        let (x, y) = pair(xy)

        if x == "D" || y == "D" { return .deleted }
        if x == "A" { return .added }
        if x == "T" || y == "T" { return .typeChanged }

        return .modified
    }

    static func renameStatus(xy: Substring) -> GitFileStatus {
        let (x, y) = pair(xy)

        if x == "D" || y == "D" { return .deleted }

        return x == "C" || y == "C" ? .copied : .renamed
    }

    static func isSubmodule(_ field: Substring) -> Bool {
        field.first == "S"
    }

    static func parseOrdinary(_ text: String) -> GitChange? {
        guard
            let (fields, path) = splitFields(text, count: FieldCount.ordinary),
            fields[0] == "1"
        else { return nil }

        let (x, y) = pair(fields[1])
        return GitChange(
            path: path,
            status: status(xy: fields[1]),
            indexStatus: x,
            worktreeStatus: y,
            isSubmodule: isSubmodule(fields[2])
        )
    }

    static func parseRenameOrCopy(_ text: String, originalPath: String?) -> GitChange? {
        guard
            let (fields, path) = splitFields(text, count: FieldCount.renameOrCopy),
            fields[0] == "2"
        else { return nil }

        let (x, y) = pair(fields[1])
        return GitChange(
            path: path,
            originalPath: originalPath,
            status: renameStatus(xy: fields[1]),
            indexStatus: x,
            worktreeStatus: y,
            isSubmodule: isSubmodule(fields[2])
        )
    }

    static func parseUnmerged(_ text: String) -> GitChange? {
        guard
            let (fields, path) = splitFields(text, count: FieldCount.unmerged),
            fields[0] == "u"
        else { return nil }

        let (x, y) = pair(fields[1])
        return GitChange(
            path: path,
            status: .conflicted,
            indexStatus: x,
            worktreeStatus: y,
            isSubmodule: isSubmodule(fields[2])
        )
    }

    static func parseUntracked(_ text: String) -> GitChange? {
        guard
            let (fields, path) = splitFields(text, count: FieldCount.untracked),
            fields[0] == "?"
        else { return nil }

        return GitChange(path: path, status: .untracked)
    }
}
