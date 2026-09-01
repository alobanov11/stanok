import Foundation

public enum GitRootResolver {

    public static func normalized(_ path: String) -> String {
        var trimmed = path
        while trimmed.count > 1, trimmed.hasSuffix("/") { trimmed.removeLast() }

        return trimmed
    }

    public static func inherited(for directory: String, from roots: Set<String>) -> String? {
        let target = normalized(directory)
        let candidates = roots
            .map(normalized)
            .filter { !$0.isEmpty }
            .filter { target == $0 || target.hasPrefix($0 == "/" ? "/" : $0 + "/") }
            .sorted { $0.count > $1.count }

        // Почему: между каталогом и корнем может лежать сабмодуль со своим .git
        for candidate in candidates where !hasNestedRepository(from: target, upTo: candidate) {
            return candidate
        }

        return nil
    }

    public static func hasNestedRepository(from directory: String, upTo root: String) -> Bool {
        var current = normalized(directory)
        let top = normalized(root)
        let manager = FileManager.default
        guard !top.isEmpty else { return false }

        while current != top, current.count > top.count {
            if manager.fileExists(atPath: current + "/.git") { return true }

            current = normalized((current as NSString).deletingLastPathComponent)
        }

        return false
    }
}
