import Foundation
import StanokKit

#if canImport(Darwin)
import Darwin
#endif

actor ClaudeEditIndex {

    fileprivate struct Identity: Equatable {

        let inode: UInt64
        let size: Int
    }

    fileprivate struct Entry {

        var identity: Identity
        var scanned: Int
        var touches: [String: Date]
        var directory: String?
    }

    fileprivate enum Limit {

        static let freshness: TimeInterval = 14 * 86400
        static let chunk = 32 * 1024 * 1024
    }

    private var entries: [String: Entry] = [:]

    func touched(under root: URL) -> ([AgentTouchedFile], Set<String>) {
        let files = Self.sessionFiles(under: root)
        var directories: Set<String> = []
        var byPath: [String: Date] = [:]

        for file in files {
            guard let entry = scan(file) else { continue }

            if let directory = entry.directory { directories.insert(directory) }

            for (path, at) in entry.touches where byPath[path] ?? .distantPast < at {
                byPath[path] = at
            }
        }

        entries = entries.filter { files.contains($0.key) }

        let touches = byPath.map { AgentTouchedFile(url: URL(filePath: $0.key), touchedAt: $0.value) }

        return (touches.sorted { $0.touchedAt > $1.touchedAt }, directories)
    }
}

private extension ClaudeEditIndex {

    static func sessionFiles(under root: URL) -> Set<String> {
        let manager = FileManager.default
        let deadline = Date().addingTimeInterval(-Limit.freshness)
        guard
            let walker = manager.enumerator(
                at: root,
                includingPropertiesForKeys: [.contentModificationDateKey, .isRegularFileKey]
            )
        else { return [] }

        var found: Set<String> = []
        for case let url as URL in walker where url.pathExtension == "jsonl" {
            let values = try? url.resourceValues(forKeys: [.contentModificationDateKey])
            guard let modified = values?.contentModificationDate, modified >= deadline else {
                continue
            }

            found.insert(url.path(percentEncoded: false))
        }

        return found
    }

    static func identity(of path: String) -> Identity? {
        var info = stat()
        guard path.withCString({ lstat($0, &info) }) == 0 else { return nil }

        return Identity(inode: UInt64(info.st_ino), size: Int(info.st_size))
    }

    func scan(_ path: String) -> Entry? {
        guard let identity = Self.identity(of: path) else {
            entries.removeValue(forKey: path)
            return nil
        }

        if
            let existing = entries[path], existing.identity.inode == identity.inode,
            existing.scanned == identity.size {
            return existing
        }

        var entry = entries[path] ?? Entry(
            identity: identity,
            scanned: 0,
            touches: [:],
            directory: nil
        )

        if entry.identity.inode != identity.inode { entry = Entry(
            identity: identity,
            scanned: 0,
            touches: [:],
            directory: nil
        ) }

        // Почему: логи только дописываются, поэтому читаем лишь новый хвост
        let from = max(entry.scanned, identity.size - Limit.chunk)
        guard let text = Self.read(path, from: from, to: identity.size) else { return entry }

        for line in text.split(separator: "\n", omittingEmptySubsequences: true) {
            Self.collect(String(line), into: &entry)
        }

        entry.identity = identity
        entry.scanned = identity.size
        entries[path] = entry
        return entry
    }

    static func read(_ path: String, from offset: Int, to end: Int) -> String? {
        guard end > offset, let handle = FileHandle(forReadingAtPath: path) else { return nil }

        defer { try? handle.close() }

        do {
            if offset > 0 { try handle.seek(toOffset: UInt64(offset)) }
            guard let data = try handle.read(upToCount: end - offset) else { return nil }

            return String(data: data, encoding: .utf8)
        } catch {
            return nil
        }
    }

    static func collect(_ line: String, into entry: inout Entry) {
        guard line.contains("\"file_path\"") || entry.directory == nil else { return }
        guard
            let data = line.data(using: .utf8),
            let record = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return }

        if entry.directory == nil, let cwd = record["cwd"] as? String { entry.directory = cwd }

        guard
            let message = record["message"] as? [String: Any],
            let blocks = message["content"] as? [[String: Any]]
        else { return }

        let at = (record["timestamp"] as? String).flatMap(Self.date(from:)) ?? Date()

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

private extension ISO8601DateFormatter {

    nonisolated(unsafe) static let touches: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
}
