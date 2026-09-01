import Foundation

enum IgnoredPaths {

    static let directories: Set<String> = [
        ".git", ".hg", ".svn", ".jj",
        ".build", ".swiftpm", "DerivedData", "Pods", "Carthage", "xcuserdata",
        "node_modules", "bower_components", ".yarn", ".pnpm-store",
        ".next", ".nuxt", ".svelte-kit", ".angular", ".astro", ".turbo",
        ".parcel-cache", ".vite", ".webpack",
        ".venv", "venv", "__pycache__", ".mypy_cache", ".pytest_cache",
        ".ruff_cache", ".tox", ".ipynb_checkpoints",
        "target", ".cargo",
        ".zig-cache", "zig-out",
        "_build", ".gradle", ".m2", ".bundle", ".terraform",
        ".cache", ".ccache", ".stack-work", ".dart_tool", "obj",
        ".idea", ".gems"
    ]

    static let directoryPairs: [[String]] = [["vendor", "bundle"]]

    static let homeDirectories: Set<String> = [
        "Library", "Applications", ".Trash", "Movies", "Music", "Pictures", "Public"
    ]

    static var homeExclusions: [String] {
        let home = URL(filePath: NSHomeDirectory())

        return homeDirectories
            .map { home.appending(path: $0, directoryHint: .isDirectory) }
            .filter { FileManager.default.fileExists(atPath: $0.path(percentEncoded: false)) }
            .map { $0.path(percentEncoded: false) }
            .sorted()
    }

    static func contains(_ url: URL) -> Bool {
        if url.pathComponents.contains(where: directories.contains) { return true }
        if containsPair(url.pathComponents) { return true }

        return isInsideExcludedHomeDirectory(url)
    }

    private static func containsPair(_ components: [String]) -> Bool {
        directoryPairs.contains { pair in
            guard components.count >= pair.count else { return false }

            return (0...(components.count - pair.count)).contains { start in
                Array(components[start..<(start + pair.count)]) == pair
            }
        }
    }

    private static func isInsideExcludedHomeDirectory(_ url: URL) -> Bool {
        let home = NSHomeDirectory()
        let path = url.path(percentEncoded: false)
        guard path.hasPrefix(home + "/") else { return false }

        let rest = String(path.dropFirst(home.count + 1))
        let first = rest.split(separator: "/", maxSplits: 1).first.map(String.init)

        return first.map(homeDirectories.contains) ?? false
    }
}
