import Foundation

enum WorkspacePaths {

    static func contains(_ root: URL, _ candidate: URL) -> Bool {
        let base = root.standardizedFileURL.path(percentEncoded: false)
        let target = candidate.standardizedFileURL.path(percentEncoded: false)
        guard target != base else { return true }

        return target.hasPrefix(base.hasSuffix("/") ? base : base + "/")
    }

    static func resolvedURL(from raw: String, relativeTo base: URL) -> URL? {
        if let url = URL(string: raw), url.scheme != nil { return url }
        if raw.hasPrefix("/") { return URL(fileURLWithPath: raw) }

        return base.appending(path: raw)
    }

    static func relativePath(for url: URL, in root: URL) -> String? {
        guard contains(root, url) else { return nil }

        let base = root.standardizedFileURL.path(percentEncoded: false)
        let target = url.standardizedFileURL.path(percentEncoded: false)
        let prefix = base.hasSuffix("/") ? base : base + "/"
        guard target != base, target.hasPrefix(prefix) else { return nil }

        return String(target.dropFirst(prefix.count))
    }

    static func resolvedURL(relative: String, in root: URL) -> URL? {
        guard !relative.isEmpty, !relative.hasPrefix("/") else { return nil }
        guard !relative.split(separator: "/").contains("..") else { return nil }

        return root.appending(path: relative)
    }

    static func resolvedSelectedFile(from repository: Repository) -> URL? {
        guard let relative = repository.workspace.selectedFile else { return nil }

        return resolvedURL(relative: relative, in: repository.url)
    }

    static func filePanelMode(from raw: String?) -> FilePanelMode? {
        switch raw {
        case "all": return .all
        case "changes": return .changes
        case "branches": return .branches
        default: return nil
        }
    }

    static func rawValue(for mode: FilePanelMode?) -> String? {
        switch mode {
        case .all: return "all"
        case .changes: return "changes"
        case .branches: return "branches"
        case nil: return nil
        }
    }
}
