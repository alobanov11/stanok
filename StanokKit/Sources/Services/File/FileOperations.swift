import Foundation

enum FileOperations {

    enum Failure: LocalizedError {

        case intoItself

        var errorDescription: String? {
            switch self {
            case .intoItself: "Нельзя поместить папку внутрь себя"
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

    @discardableResult
    static func copy(_ urls: [URL], into directory: URL) throws -> [URL] {
        var targets: [URL] = []

        for url in urls {
            guard !isNested(directory, inside: url) else { throw Failure.intoItself }

            let target = available(named: url.lastPathComponent, in: directory)
            try FileManager.default.copyItem(at: url, to: target)
            targets.append(target)
        }

        return targets
    }

    @discardableResult
    static func move(_ urls: [URL], into directory: URL) throws -> [URL] {
        var targets: [URL] = []

        for url in urls {
            guard !isNested(directory, inside: url) else { throw Failure.intoItself }

            let parent = url.deletingLastPathComponent().standardizedFileURL
            guard parent != directory.standardizedFileURL else {
                targets.append(url)
                continue
            }

            let target = available(named: url.lastPathComponent, in: directory)
            try FileManager.default.moveItem(at: url, to: target)
            targets.append(target)
        }

        return targets
    }

    static func looksNested(_ candidate: URL, inside root: URL) -> Bool {
        let base = root.standardizedFileURL.path(percentEncoded: false)
        let path = candidate.standardizedFileURL.path(percentEncoded: false)
        guard base != path else { return true }

        return path.hasPrefix(base.hasSuffix("/") ? base : base + "/")
    }

    static func isNested(_ candidate: URL, inside root: URL) -> Bool {
        let base = root.standardizedFileURL.resolvingSymlinksInPath()
            .path(percentEncoded: false)
        let path = candidate.standardizedFileURL.resolvingSymlinksInPath()
            .path(percentEncoded: false)
        guard base != path else { return true }

        return path.hasPrefix(base.hasSuffix("/") ? base : base + "/")
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
