import AppKit

@MainActor
enum FileIcons {

    private static var cache: [String: NSImage] = [:]

    static func icon(for url: URL, isDirectory: Bool) -> NSImage {
        let ext = url.pathExtension.lowercased()
        let key = ext.isEmpty ? (isDirectory ? "/directory" : "/file") : ext

        if let cached = cache[key] { return cached }

        let icon = NSWorkspace.shared.icon(forFile: url.path(percentEncoded: false))
        cache[key] = icon
        return icon
    }
}
