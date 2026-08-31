import AppKit

enum FilePasteboard {

    static var urls: [URL] {
        let options: [NSPasteboard.ReadingOptionKey: Any] = [.urlReadingFileURLsOnly: true]
        let items = NSPasteboard.general.readObjects(forClasses: [NSURL.self], options: options)

        return (items as? [URL]) ?? []
    }

    static func write(_ urls: [URL]) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.writeObjects(urls as [NSURL])
    }
}
