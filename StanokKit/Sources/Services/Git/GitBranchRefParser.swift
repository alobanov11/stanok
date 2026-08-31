import Foundation

public enum GitBranchRefParser {

    private enum Prefix {

        static let heads = "refs/heads/"
        static let remotes = "refs/remotes/"
    }

    public static func parse(_ data: Data) -> [GitBranchRef] {
        decode(data)
            .split(separator: "\n", omittingEmptySubsequences: true)
            .compactMap(parseLine)
    }
}

private extension GitBranchRefParser {

    static func parseLine(_ line: Substring) -> GitBranchRef? {
        let fields = line.split(separator: "\u{0}", omittingEmptySubsequences: false)
        guard fields.count == 3, fields[1].isEmpty else { return nil }

        let fullName = String(fields[0])
        let isCurrent = fields[2] == "*"

        if fullName.hasPrefix(Prefix.heads) {
            return localRef(fullName, isCurrent: isCurrent)
        }

        if fullName.hasPrefix(Prefix.remotes) {
            return remoteRef(fullName, isCurrent: isCurrent)
        }

        return nil
    }

    static func localRef(_ fullName: String, isCurrent: Bool) -> GitBranchRef? {
        let displayName = String(fullName.dropFirst(Prefix.heads.count))
        guard !displayName.isEmpty else { return nil }

        return GitBranchRef(
            fullName: fullName,
            displayName: displayName,
            kind: .local,
            isCurrent: isCurrent
        )
    }

    static func remoteRef(_ fullName: String, isCurrent: Bool) -> GitBranchRef? {
        let rest = fullName.dropFirst(Prefix.remotes.count)
        guard let separator = rest.firstIndex(of: "/") else { return nil }

        let remoteName = String(rest[rest.startIndex..<separator])
        let displayName = String(rest[rest.index(after: separator)...])
        guard !remoteName.isEmpty, !displayName.isEmpty else { return nil }

        return GitBranchRef(
            fullName: fullName,
            displayName: displayName,
            kind: .remote,
            remoteName: remoteName,
            isCurrent: isCurrent
        )
    }

    static func decode(_ data: Data) -> String {
        // swiftlint:disable:next optional_data_string_conversion
        String(decoding: data, as: UTF8.self)
    }
}
