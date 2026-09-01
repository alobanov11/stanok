import Foundation
import StanokKit

#if canImport(Darwin)
import Darwin
#endif

actor ClaudeEditIndex {

    struct Identity: Equatable {

        let inode: UInt64
        let size: Int
        let modified: TimeInterval
    }

    struct Entry {

        var identity: Identity
        var scanned: Int
        var touches: [String: Date]
        var directory: String?
    }

    enum Limit {

        static let freshness: TimeInterval = 14 * 86400
        static let firstChunk = 8 * 1024 * 1024
        static let budget = 64 * 1024 * 1024
    }

    private var entries: [String: Entry] = [:]

    func touched(under root: URL) async -> ([AgentTouchedFile], Set<String>) {
        let files = Self.sessionFiles(under: root)
        var directories: Set<String> = []
        var byPath: [String: Date] = [:]
        var budget = Limit.budget

        for file in files {
            guard !Task.isCancelled else { break }

            guard let entry = scan(file, budget: &budget) else { continue }

            if let directory = entry.directory { directories.insert(directory) }

            for (path, at) in entry.touches where byPath[path] ?? .distantPast < at {
                byPath[path] = at
            }
        }

        let known = Set(files)
        entries = entries.filter { known.contains($0.key) }

        let touches = byPath.map {
            AgentTouchedFile(url: URL(filePath: $0.key), touchedAt: $0.value)
        }

        return (touches.sorted { $0.touchedAt > $1.touchedAt }, directories)
    }
}

private extension ClaudeEditIndex {

    static func sessionFiles(under root: URL) -> [String] {
        let keys: [URLResourceKey] = [.contentModificationDateKey, .isRegularFileKey]
        let deadline = Date().addingTimeInterval(-Limit.freshness)
        guard
            let walker = FileManager.default.enumerator(
                at: root,
                includingPropertiesForKeys: keys
            )
        else { return [] }

        var found: [(path: String, modified: Date)] = []
        for case let url as URL in walker where url.pathExtension == "jsonl" {
            let values = try? url.resourceValues(forKeys: Set(keys))
            guard
                values?.isRegularFile == true,
                let modified = values?.contentModificationDate,
                modified >= deadline
            else { continue }

            found.append((url.path(percentEncoded: false), modified))
        }

        return found.sorted { $0.modified > $1.modified }.map(\.path)
    }

    static func identity(of path: String) -> Identity? {
        var info = Foundation.stat()
        guard path.withCString({ stat($0, &info) }) == 0 else { return nil }

        let modified = TimeInterval(info.st_mtimespec.tv_sec)
            + TimeInterval(info.st_mtimespec.tv_nsec) / 1_000_000_000

        return Identity(inode: UInt64(info.st_ino), size: Int(info.st_size), modified: modified)
    }

    func scan(_ path: String, budget: inout Int) -> Entry? {
        guard let identity = Self.identity(of: path) else {
            entries.removeValue(forKey: path)
            return nil
        }

        var entry = entries[path]
        // Почему: лог могли заменить или переписать на месте, тогда прежний офсет уже не о том файле
        if let known = entry, Self.rewritten(known, into: identity) {
            entry = Entry(identity: identity, scanned: 0, touches: [:], directory: nil)
        } else if entry == nil {
            entry = Entry(identity: identity, scanned: 0, touches: [:], directory: nil)
        }

        guard var entry else { return nil }
        guard entry.scanned < identity.size, budget > 0 else { return entry }

        let start = entry.scanned == 0
            ? max(0, identity.size - Limit.firstChunk)
            : entry.scanned
        let length = min(identity.size - start, budget)
        guard let chunk = Self.read(path, from: start, length: length) else { return entry }

        let consumed = Self.collect(chunk, skipsHead: start > entry.scanned, into: &entry)
        budget -= chunk.count
        entry.identity = identity
        // Почему: строка длиннее окна чтения иначе перечитывалась бы вечно
        entry.scanned = start + (consumed > 0 ? consumed : chunk.count)
        entries[path] = entry
        return entry
    }

    static func rewritten(_ entry: Entry, into identity: Identity) -> Bool {
        if entry.identity.inode != identity.inode { return true }
        if identity.size < entry.scanned { return true }

        return identity.size == entry.scanned && identity.modified != entry.identity.modified
    }

    static func read(_ path: String, from offset: Int, length: Int) -> Data? {
        guard length > 0, let handle = FileHandle(forReadingAtPath: path) else { return nil }

        defer { try? handle.close() }

        do {
            if offset > 0 { try handle.seek(toOffset: UInt64(offset)) }

            return try handle.read(upToCount: length)
        } catch {
            return nil
        }
    }

    static func collect(_ chunk: Data, skipsHead: Bool, into entry: inout Entry) -> Int {
        let newline = UInt8(ascii: "\n")
        guard let last = chunk.lastIndex(of: newline) else { return 0 }

        let head = skipsHead ? chunk.firstIndex(of: newline).map { $0 + 1 } : chunk.startIndex
        let consumed = chunk.distance(from: chunk.startIndex, to: last) + 1
        guard let head, head <= last else { return consumed }

        for line in chunk[head...last].split(separator: newline) {
            read(line: Data(line), into: &entry)
        }

        return consumed
    }

    static func read(line: Data, into entry: inout Entry) {
        let interesting = line.holds("\"file_path\"") || line.holds("\"notebook_path\"")
        guard interesting || entry.directory == nil else { return }

        guard let record = try? JSONSerialization.jsonObject(with: line) as? [String: Any]
        else { return }

        if entry.directory == nil, let cwd = record["cwd"] as? String { entry.directory = cwd }

        guard
            interesting,
            let at = (record["timestamp"] as? String).flatMap(Self.date(from:)),
            let message = record["message"] as? [String: Any],
            let blocks = message["content"] as? [[String: Any]]
        else { return }

        for block in blocks where block["type"] as? String == "tool_use" {
            guard
                let input = block["input"] as? [String: Any],
                let file = (input["file_path"] ?? input["notebook_path"]) as? String,
                file.hasPrefix("/")
            else { continue }

            entry.touches[file] = at
        }
    }

    static func date(from raw: String) -> Date? {
        ISO8601DateFormatter.touches.date(from: raw)
    }
}

private extension Data {

    func holds(_ marker: String) -> Bool {
        range(of: Data(marker.utf8)) != nil
    }
}

private extension ISO8601DateFormatter {

    nonisolated(unsafe) static let touches: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
}
