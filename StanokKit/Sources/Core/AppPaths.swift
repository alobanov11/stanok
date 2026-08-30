import Foundation

public enum AppPaths {

    public static var configDirectory: URL {
        let xdg = ProcessInfo.processInfo.environment["XDG_CONFIG_HOME"]?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let root = xdg
            .flatMap { $0.hasPrefix("/") ? URL(filePath: $0, directoryHint: .isDirectory) : nil }
            ?? FileManager.default.homeDirectoryForCurrentUser
            .appending(path: ".config", directoryHint: .isDirectory)
        return root.appending(path: "stanok", directoryHint: .isDirectory)
    }

    public static var ghosttyConfig: URL {
        configDirectory.appending(path: "config.ghostty", directoryHint: .notDirectory)
    }

    public static var repositories: URL {
        configDirectory.appending(path: "repositories.json", directoryHint: .notDirectory)
    }

    public static var shellInit: URL {
        configDirectory
            .appending(path: "shell", directoryHint: .isDirectory)
            .appending(path: "init.zsh", directoryHint: .notDirectory)
    }
}
