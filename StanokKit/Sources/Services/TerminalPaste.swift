import AppKit

public enum TerminalPaste {

    public static func text(from pasteboard: NSPasteboard = .general) -> String? {
        let files = fileURLs(on: pasteboard)
        if !files.isEmpty {
            return ShellQuoting.posixQuote(files.map { $0.path(percentEncoded: false) })
        }

        if let string = pasteboard.string(forType: .string), !string.isEmpty {
            return string
        }

        guard let image = savedImage(from: pasteboard) else { return nil }

        return ShellQuoting.posixQuote([image.path(percentEncoded: false)])
    }
}

private extension TerminalPaste {

    static func fileURLs(on pasteboard: NSPasteboard) -> [URL] {
        let options: [NSPasteboard.ReadingOptionKey: Any] = [.urlReadingFileURLsOnly: true]
        let items = pasteboard.readObjects(forClasses: [NSURL.self], options: options)

        return (items as? [URL]) ?? []
    }

    static func savedImage(from pasteboard: NSPasteboard) -> URL? {
        guard let data = pngData(from: pasteboard) else { return nil }

        let directory = FileManager.default.temporaryDirectory
            .appending(path: "stanok-paste", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let name = "clipboard-\(UUID().uuidString.prefix(8)).png"
        let url = directory.appending(path: name)

        do {
            try data.write(to: url, options: .atomic)
        } catch {
            Log.terminal.error("cannot save pasted image: \(error.localizedDescription)")
            return nil
        }

        return url
    }

    static func pngData(from pasteboard: NSPasteboard) -> Data? {
        if let png = pasteboard.data(forType: .png) { return png }

        guard
            let tiff = pasteboard.data(forType: .tiff),
            let bitmap = NSBitmapImageRep(data: tiff)
        else { return nil }

        return bitmap.representation(using: .png, properties: [:])
    }
}
