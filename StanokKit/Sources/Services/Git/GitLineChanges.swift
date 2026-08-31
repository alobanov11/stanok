import Foundation

enum GitLineChanges {

    static func load(for url: URL) async -> [Int: LineChange] {
        let directory = url.deletingLastPathComponent().path(percentEncoded: false)
        let path = url.path(percentEncoded: false)

        let diff = await GitProcessRunner.run([
            "-C", directory, "diff", "HEAD", "-U0", "--no-color", "--", path
        ])

        guard diff.exitCode == 0 else { return [:] }

        let text = String(data: diff.standardOutput, encoding: .utf8) ?? ""

        return parse(text)
    }

    static func parse(_ diff: String) -> [Int: LineChange] {
        var changes: [Int: LineChange] = [:]

        for line in diff.split(separator: "\n", omittingEmptySubsequences: false)
            where line.hasPrefix("@@") {
            guard let hunk = hunk(from: String(line)) else { continue }

            guard hunk.added > 0 else {
                changes[max(hunk.start, 1)] = .removed
                continue
            }

            let kind: LineChange = hunk.removed > 0 ? .modified : .added
            for number in hunk.start..<(hunk.start + hunk.added) {
                changes[number] = kind
            }
        }

        return changes
    }

    private static func hunk(from line: String) -> (start: Int, added: Int, removed: Int)? {
        let parts = line.split(separator: " ")
        guard parts.count >= 3, parts[1].hasPrefix("-"), parts[2].hasPrefix("+") else { return nil }

        let removed = span(String(parts[1].dropFirst()))
        let added = span(String(parts[2].dropFirst()))

        return (added.start, added.count, removed.count)
    }

    private static func span(_ text: String) -> (start: Int, count: Int) {
        let parts = text.split(separator: ",")
        let start = Int(parts.first ?? "") ?? 0
        let count = parts.count > 1 ? Int(parts[1]) ?? 0 : 1

        return (start, count)
    }
}
