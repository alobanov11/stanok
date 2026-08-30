import Foundation

enum FileOperations {

    enum Failure: LocalizedError {

        case intoItself

        var errorDescription: String? {
            switch self {
            case .intoItself: "Нельзя вставить папку внутрь себя"
            }
        }
    }

    static func createFile(named name: String, in directory: URL) throws {
        try Data().write(to: directory.appending(path: name), options: .withoutOverwriting)
    }

    static func createDirectory(named name: String, in directory: URL) throws {
        try FileManager.default.createDirectory(
            at: directory.appending(path: name),
            withIntermediateDirectories: false
        )
    }

    static func rename(_ url: URL, to name: String) throws {
        let target = url.deletingLastPathComponent().appending(path: name)
        guard target != url else { return }

        try FileManager.default.moveItem(at: url, to: target)
    }

    static func trash(_ url: URL) throws {
        try FileManager.default.trashItem(at: url, resultingItemURL: nil)
    }

    static func copy(_ urls: [URL], into directory: URL) throws {
        for url in urls {
            guard !contains(url, directory) else { throw Failure.intoItself }

            let target = available(named: url.lastPathComponent, in: directory)
            try FileManager.default.copyItem(at: url, to: target)
        }
    }

    private static func contains(_ parent: URL, _ child: URL) -> Bool {
        let root = parent.standardizedFileURL.path(percentEncoded: false)
        let nested = child.standardizedFileURL.path(percentEncoded: false)
        guard root != nested else { return true }

        return nested.hasPrefix(root.hasSuffix("/") ? root : root + "/")
    }

    private static func available(named name: String, in directory: URL) -> URL {
        let manager = FileManager.default
        var candidate = directory.appending(path: name)
        guard manager.fileExists(atPath: candidate.path(percentEncoded: false)) else {
            return candidate
        }

        let base = (name as NSString).deletingPathExtension
        let suffix = (name as NSString).pathExtension
        var index = 2

        repeat {
            let next = suffix.isEmpty ? "\(base) \(index)" : "\(base) \(index).\(suffix)"
            candidate = directory.appending(path: next)
            index += 1
        } while manager.fileExists(atPath: candidate.path(percentEncoded: false))

        return candidate
    }
}
