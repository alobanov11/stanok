import AppKit
import UniformTypeIdentifiers

@MainActor
enum FileIcons {

    private static var cache: [String: NSImage] = [:]

    static func icon(for url: URL, isDirectory: Bool) -> NSImage {
        let ext = url.pathExtension.lowercased()
        let key = isDirectory ? "/directory" : (ext.isEmpty ? "/file" : ext)

        if let cached = cache[key] { return cached }

        let icon = image(forExtension: ext, isDirectory: isDirectory)
        cache[key] = icon
        return icon
    }

    private static func image(forExtension ext: String, isDirectory: Bool) -> NSImage {
        if isDirectory {
            return NSWorkspace.shared.icon(for: .folder)
        }

        guard !ext.isEmpty, let type = UTType(filenameExtension: ext) else {
            return NSWorkspace.shared.icon(for: .data)
        }

        return NSWorkspace.shared.icon(for: type)
    }
}
