import Foundation

enum FileOperations {

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
}
