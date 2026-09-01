import Foundation

enum GitLineChanges {

    static func load(for url: URL) async -> GitFileChanges {
        let directory = url.deletingLastPathComponent().path(percentEncoded: false)
        let path = url.path(percentEncoded: false)

        let diff = await GitProcessRunner.run([
            "--no-optional-locks", "-C", directory, "diff", "HEAD", "-U0", "--no-color", "--", path
        ])

        if diff.exitCode == 0, !diff.standardOutput.isEmpty {
            return parse(String(data: diff.standardOutput, encoding: .utf8) ?? "")
        }

        let insideWorkTree = await GitProcessRunner.run([
            "--no-optional-locks", "-C", directory, "rev-parse", "--is-inside-work-tree"
        ]).exitCode == 0

        guard insideWorkTree else { return .none }

        let tracked = await GitProcessRunner.run([
            "--no-optional-locks", "-C", directory, "ls-files", "--error-unmatch", "--", path
        ]).exitCode == 0

        guard !tracked else { return .none }

        let fresh = await GitProcessRunner.run([
            "--no-optional-locks", "-C", directory,
            "diff", "--no-index", "-U0", "--no-color", "--", "/dev/null", path
        ])

        guard fresh.exitCode == 0 || fresh.exitCode == 1 else { return .none }

        return parse(String(data: fresh.standardOutput, encoding: .utf8) ?? "")
    }

    static func parse(_ diff: String) -> GitFileChanges {
        var kinds: [Int: LineChange] = [:]
        var removed: [Int: [String]] = [:]
        var anchor: Int?

        for raw in diff.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = String(raw)

            if line.hasPrefix("diff --git") {
                anchor = nil
                continue
            }

            if line.hasPrefix("@@") {
                guard let hunk = hunk(from: line) else { continue }

                anchor = max(hunk.start, 1)

                guard hunk.added > 0 else {
                    kinds[max(hunk.start, 1)] = .removed
                    continue
                }

                let kind: LineChange = hunk.removed > 0 ? .modified : .added
                for number in hunk.start..<(hunk.start + hunk.added) {
                    kinds[number] = kind
                }
                continue
            }

            guard let anchor, line.hasPrefix("-") else { continue }

            removed[anchor, default: []].append(String(line.dropFirst()))
        }

        return GitFileChanges(kinds: kinds, removed: removed)
    }
}

private extension GitLineChanges {

    static func hunk(from line: String) -> (start: Int, added: Int, removed: Int)? {
        let parts = line.split(separator: " ")
        guard parts.count >= 3, parts[1].hasPrefix("-"), parts[2].hasPrefix("+") else { return nil }

        let removed = span(String(parts[1].dropFirst()))
        let added = span(String(parts[2].dropFirst()))

        return (added.start, added.count, removed.count)
    }

    static func span(_ text: String) -> (start: Int, count: Int) {
        let parts = text.split(separator: ",")
        let start = Int(parts.first ?? "") ?? 0
        let count = parts.count > 1 ? Int(parts[1]) ?? 0 : 1

        return (start, count)
    }
}
