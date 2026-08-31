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
        ".idea", ".gems", "vendor/bundle"
    ]

    static func contains(_ url: URL) -> Bool {
        url.pathComponents.contains { directories.contains($0) }
    }
}
