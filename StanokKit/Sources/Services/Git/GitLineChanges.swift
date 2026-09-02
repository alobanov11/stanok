import Foundation

enum GitLineChanges {

    private enum Limit {

        static let diff = 2 * 1024 * 1024
        static let removedPerAnchor = 500
        static let lines = 5000
    }

    static func load(
        for url: URL,
        source: ReviewSource = .worktree,
        root: String? = nil
    ) async -> GitFileChanges {
        // Почему: каталога файла может уже не быть, а корень репозитория на месте всегда
        let directory = root ?? url.deletingLastPathComponent().path(percentEncoded: false)
        let path = url.path(percentEncoded: false)
        let arguments = if case let .commit(sha) = source {
            [
                "show", "--format=", "-U0", "--no-color",
                "--diff-merges=first-parent", sha, "--", path
            ]
        } else {
            ["diff", "HEAD", "-U0", "--no-color", "--", path]
        }

        let diff = await GitProcessRunner.run(
            ["--no-optional-locks", "-C", directory] + arguments,
            limit: Limit.diff
        )

        // Почему: гигантский дифф незачем поднимать в память ради полос на полях
        if diff.exitCode == 0, !diff.standardOutput.isEmpty {
            guard !diff.isTruncated else { return .none }

            return parse(String(data: diff.standardOutput, encoding: .utf8) ?? "")
        }

        // Почему: для коммита рабочая копия — другая ревизия, подмешивать её нельзя
        guard source == .worktree else { return .none }

        return await untracked(directory: directory, path: path)
    }

    static func untracked(directory: String, path: String) async -> GitFileChanges {
        let insideWorkTree = await GitProcessRunner.run([
            "--no-optional-locks", "-C", directory, "rev-parse", "--is-inside-work-tree"
        ]).exitCode == 0

        guard insideWorkTree else { return .none }

        let known = await GitProcessRunner.run([
            "--no-optional-locks", "-C", directory, "ls-files", "--error-unmatch", "--", path
        ]).exitCode == 0

        guard !known else { return .none }

        let fresh = await GitProcessRunner.run([
            "--no-optional-locks", "-C", directory,
            "diff", "--no-index", "-U0", "--no-color", "--", "/dev/null", path
        ], limit: Limit.diff)

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
                apply(hunk, into: &kinds)
                continue
            }

            guard let anchor, line.hasPrefix("-") else { continue }

            // Почему: тысячи удалённых строк под одной полосой всё равно не читают
            if removed[anchor, default: []].count < Limit.removedPerAnchor {
                removed[anchor, default: []].append(String(line.dropFirst()))
            }
        }

        return GitFileChanges(kinds: kinds, removed: removed)
    }
}

private extension GitLineChanges {

    static func apply(
        _ hunk: (start: Int, added: Int, removed: Int),
        into kinds: inout [Int: LineChange]
    ) {
        guard hunk.added > 0 else {
            kinds[max(hunk.start, 1)] = .removed

            return
        }

        let kind: LineChange = hunk.removed > 0 ? .modified : .added

        for number in hunk.start..<(hunk.start + hunk.added) {
            kinds[number] = kind
        }
    }

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
