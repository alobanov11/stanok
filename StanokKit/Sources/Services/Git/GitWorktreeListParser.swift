import Foundation

public enum GitWorktreeListParser {

    private enum Prefix {

        static let worktree = "worktree "
        static let branch = "branch "
    }

    public static func parse(_ data: Data) -> [GitWorktreeEntry] {
        var entries: [GitWorktreeEntry] = []
        let tokens = decode(data).split(separator: "\u{0}", omittingEmptySubsequences: false)

        var lines: [Substring] = []

        for token in tokens {
            guard !token.isEmpty else {
                if let entry = makeEntry(lines) { entries.append(entry) }
                lines = []
                continue
            }

            lines.append(token)
        }

        if let entry = makeEntry(lines) { entries.append(entry) }
        return entries
    }

    private static func makeEntry(_ lines: [Substring]) -> GitWorktreeEntry? {
        guard let first = lines.first, first.hasPrefix(Prefix.worktree) else { return nil }

        let path = String(first.dropFirst(Prefix.worktree.count))
        let branch = lines
            .first { $0.hasPrefix(Prefix.branch) }
            .map { String($0.dropFirst(Prefix.branch.count)) }

        return GitWorktreeEntry(path: path, branchFullName: branch)
    }

    private static func decode(_ data: Data) -> String {
        // swiftlint:disable:next optional_data_string_conversion
        String(decoding: data, as: UTF8.self)
    }
}
