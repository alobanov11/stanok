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
            guard let text = String(data: chunks[index], encoding: .utf8), let prefix = text.first
            else {
                index += 1
                continue
            }

            switch prefix {
            case "1":
                if let change = parseOrdinary(text) { changes.append(change) }
                index += 1

            case "2":
                let originalPath = index + 1 < chunks.count
                    ? String(data: chunks[index + 1], encoding: .utf8)
                    : nil
                if let change = parseRenameOrCopy(text, originalPath: originalPath) {
                    changes.append(change)
                }
                index += 2

            case "u":
                if let change = parseUnmerged(text) { changes.append(change) }
                index += 1

            case "?":
                if let change = parseUntracked(text) { changes.append(change) }
                index += 1

            default:
                index += 1
            }
        }

        return changes
    }

    private static func splitFields(
        _ text: String,
        count: Int
    ) -> (fields: [Substring], path: String)? {
        let parts = text.split(separator: " ", maxSplits: count, omittingEmptySubsequences: false)
        guard parts.count == count + 1 else { return nil }

        return (Array(parts[0..<count]), String(parts[count]))
    }

    private static func status(xy: Substring, isRenameOrCopy: Bool) -> GitFileStatus {
        let characters = Array(xy)
        let x = characters.first
        let y = characters.count > 1 ? characters[1] : nil

        if x == "D" || y == "D" { return .deleted }
        if isRenameOrCopy { return x == "C" || y == "C" ? .copied : .renamed }
        if x == "A" { return .added }
        if x == "T" || y == "T" { return .typeChanged }
        return .modified
    }

    private static func isSubmodule(_ field: Substring) -> Bool {
        field.first == "S"
    }

    private static func parseOrdinary(_ text: String) -> GitChange? {
        guard let (fields, path) = splitFields(text, count: FieldCount.ordinary) else { return nil }

        return GitChange(
            path: path,
            status: status(xy: fields[1], isRenameOrCopy: false),
            isSubmodule: isSubmodule(fields[2])
        )
    }

    private static func parseRenameOrCopy(_ text: String, originalPath: String?) -> GitChange? {
        guard let (fields, path) = splitFields(text, count: FieldCount.renameOrCopy) else {
            return nil
        }

        return GitChange(
            path: path,
            originalPath: originalPath,
            status: status(xy: fields[1], isRenameOrCopy: true),
            isSubmodule: isSubmodule(fields[2])
        )
    }

    private static func parseUnmerged(_ text: String) -> GitChange? {
        guard let (fields, path) = splitFields(text, count: FieldCount.unmerged) else { return nil }

        return GitChange(path: path, status: .conflicted, isSubmodule: isSubmodule(fields[2]))
    }

    private static func parseUntracked(_ text: String) -> GitChange? {
        guard let (_, path) = splitFields(text, count: FieldCount.untracked) else { return nil }

        return GitChange(path: path, status: .untracked)
    }
}
