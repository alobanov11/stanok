import Foundation

enum ClaudeProjectDirectoryResolver {

    static func resolve(projectURL: URL, root: URL) -> URL? {
        for candidate in candidatePaths(for: projectURL) {
            let directory = root.appending(path: candidate, directoryHint: .isDirectory)
            var isDirectory: ObjCBool = false
            let exists = FileManager.default.fileExists(
                atPath: directory.path(percentEncoded: false),
                isDirectory: &isDirectory
            )
            if exists, isDirectory.boolValue { return directory }
        }

        return nil
    }
}

private extension ClaudeProjectDirectoryResolver {

    static func candidatePaths(for projectURL: URL) -> [String] {
        let raw = projectURL.path(percentEncoded: false)
        let standardized = projectURL.standardizedFileURL.path(percentEncoded: false)
        let resolved = projectURL.resolvingSymlinksInPath().path(percentEncoded: false)
        let withoutTrailingSlash = trimTrailingSlash(raw)

        var seen = Set<String>()
        var results: [String] = []
        for candidate in [raw, standardized, resolved, withoutTrailingSlash] {
            let encoded = encode(candidate)
            guard seen.insert(encoded).inserted else { continue }

            results.append(encoded)
        }

        return results
    }

    static func trimTrailingSlash(_ path: String) -> String {
        guard path.count > 1, path.hasSuffix("/") else { return path }

        return String(path.dropLast())
    }

    static func encode(_ path: String) -> String {
        ClaudeProjectPathEncoder.encode(path)
    }
}
