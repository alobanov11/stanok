import Foundation

enum WorkingDirectoryReport {

    static func normalizedPath(_ raw: String) -> String {
        guard raw.count > 1, raw.hasSuffix("/") else { return raw }

        return String(raw.dropLast())
    }

    static func urls(fromPwd raw: String) -> (reported: URL, identity: URL)? {
        let path = normalizedPath(raw)
        guard path.hasPrefix("/") else { return nil }

        let reported = URL(fileURLWithPath: path)
        return (reported, reported.resolvingSymlinksInPath())
    }
}
