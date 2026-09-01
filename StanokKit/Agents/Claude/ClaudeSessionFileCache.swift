import Foundation

#if canImport(Darwin)
import Darwin
#endif

actor ClaudeSessionFileCache {

    struct Resolution: Equatable, Sendable {

        let sessionID: String?
        let title: String?
        let cwd: String?
        let firstUserMessageText: String?
        let modifiedAt: Date
    }

    private struct Identity: Equatable {

        let device: Int32
        let inode: UInt64
        let size: Int
        let modifiedAt: Date
    }

    private struct Entry {

        var identity: Identity
        var result: ClaudeSessionRecordScanner.Result
    }

    private struct StatInfo {

        let isRegular: Bool
        let device: Int32
        let inode: UInt64
        let size: Int
        let modifiedAt: Date
    }

    private enum Limits {

        static let headCap = 512 * 1024
        static let tailCap = 256 * 1024
    }

    private var entries: [String: Entry] = [:]

    private static func readRange(_ path: String, from offset: Int, upTo length: Int) -> Data? {
        guard length > offset, let handle = FileHandle(forReadingAtPath: path) else { return nil }
        defer { try? handle.close() }

        do {
            if offset > 0 { try handle.seek(toOffset: UInt64(offset)) }
            return try handle.read(upToCount: length - offset)
        } catch {
            return nil
        }
    }

    private static func stat(_ path: String) -> StatInfo? {
        var info = Foundation.stat()
        guard path.withCString({ lstat($0, &info) }) == 0 else { return nil }

        let isRegular = (info.st_mode & S_IFMT) == S_IFREG
        let seconds = TimeInterval(info.st_mtimespec.tv_sec)
            + TimeInterval(info.st_mtimespec.tv_nsec) / 1_000_000_000

        return StatInfo(
            isRegular: isRegular,
            device: info.st_dev,
            inode: UInt64(info.st_ino),
            size: Int(info.st_size),
            modifiedAt: Date(timeIntervalSince1970: seconds)
        )
    }

    func resolve(path: String) -> Resolution? {
        guard let info = Self.stat(path), info.isRegular else {
            entries.removeValue(forKey: path)
            return nil
        }

        let identity = Identity(
            device: info.device,
            inode: info.inode,
            size: info.size,
            modifiedAt: info.modifiedAt
        )

        if let existing = entries[path], existing.identity == identity {
            return resolution(from: existing.result, modifiedAt: identity.modifiedAt)
        }

        let targetLength = min(identity.size, Limits.headCap)
        guard targetLength > 0 else {
            entries[path] = Entry(identity: identity, result: .empty)
            return resolution(from: .empty, modifiedAt: identity.modifiedAt)
        }

        guard let headBytes = Self.readRange(path, from: 0, upTo: targetLength) else {
            return entries[path].map {
                resolution(from: $0.result, modifiedAt: $0.identity.modifiedAt)
            }
        }

        var result = ClaudeSessionRecordScanner.scan(headBytes)
        if result.title == nil, identity.size > Limits.headCap {
            let tailStart = max(identity.size - Limits.tailCap, targetLength)
            let tail = Self.readRange(path, from: tailStart, upTo: identity.size) ?? Data()
            result = result.filling(from: ClaudeSessionRecordScanner.scan(tail))
        }

        entries[path] = Entry(identity: identity, result: result)
        return resolution(from: result, modifiedAt: identity.modifiedAt)
    }

    func purge(keeping validPaths: Set<String>) {
        entries = entries.filter { validPaths.contains($0.key) }
    }

    private func resolution(
        from result: ClaudeSessionRecordScanner.Result,
        modifiedAt: Date
    ) -> Resolution {
        Resolution(
            sessionID: result.sessionID,
            title: result.title,
            cwd: result.cwd,
            firstUserMessageText: result.firstUserMessageText,
            modifiedAt: modifiedAt
        )
    }
}
