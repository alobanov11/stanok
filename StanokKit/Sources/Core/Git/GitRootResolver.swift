import Foundation

public enum GitRootResolver {

    public static func inherited(for directory: String, from roots: Set<String>) -> String? {
        let candidates = roots
            .filter { directory == $0 || directory.hasPrefix($0 + "/") }
            .sorted { $0.count > $1.count }

        // Почему: между каталогом и корнем может лежать сабмодуль со своим .git
        for candidate in candidates where !hasNestedRepository(from: directory, upTo: candidate) {
            return candidate
        }

        return nil
    }

    public static func hasNestedRepository(from directory: String, upTo root: String) -> Bool {
        var current = URL(filePath: directory)
        let manager = FileManager.default

        while current.path(percentEncoded: false) != root {
            let marker = current.appending(path: ".git").path(percentEncoded: false)
            if manager.fileExists(atPath: marker) { return true }

            let parent = current.deletingLastPathComponent()
            guard parent != current else { return false }

            current = parent
        }

        return false
    }
}
