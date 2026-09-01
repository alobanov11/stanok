import Foundation

#if canImport(Darwin)
import Darwin
#endif

actor ClaudeSessionFileCache {

    enum Lookup: Sendable {

        case ready(Resolution)
        case missing(Identity)
        case gone
    }

    struct Resolution: Equatable, Sendable {

        let sessionID: String?
        let title: String?
        let cwd: String?
        let firstUserMessageText: String?
        let modifiedAt: Date
    }

    struct Identity: Equatable, Sendable {

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

        static let headCap = 16 * 1024
        static let tailCap = 64 * 1024
    }

    private var entries: [String: Entry] = [:]

    // Почему: чтение вне актора, иначе тысячи логов разбираются строго по одному
    nonisolated static func scanned(
        _ path: String,
        identity: Identity
    ) -> ClaudeSessionRecordScanner.Result? {
        let targetLength = min(identity.size, Limits.headCap)
        guard targetLength > 0 else { return .empty }

        guard let headBytes = Self.readRange(path, from: 0, upTo: targetLength) else { return nil }

        let result = ClaudeSessionRecordScanner.scan(headBytes)
        guard result.title == nil, identity.size > Limits.headCap else { return result }

        let tailStart = max(identity.size - Limits.tailCap, targetLength)
        let tail = Self.readRange(path, from: tailStart, upTo: identity.size) ?? Data()

        return result.filling(from: ClaudeSessionRecordScanner.scan(tail))
    }

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

    // Почему: разбор идёт в вызывающей задаче, актор только хранит и отдаёт готовое
    nonisolated func resolve(path: String) async -> Resolution? {
        switch await lookup(path: path) {
        case .gone:
            return nil

        case let .ready(resolution):
            return resolution

        case let .missing(identity):
            let scanned = Self.scanned(path, identity: identity)

            return await fill(path: path, identity: identity, result: scanned)
        }
    }

    func lookup(path: String) -> Lookup {
        guard let info = Self.stat(path), info.isRegular else {
            entries.removeValue(forKey: path)
            return .gone
        }

        let identity = Identity(
            device: info.device,
            inode: info.inode,
            size: info.size,
            modifiedAt: info.modifiedAt
        )

        if let existing = entries[path], existing.identity == identity {
            return .ready(resolution(from: existing.result, modifiedAt: identity.modifiedAt))
        }

        return .missing(identity)
    }

    func fill(
        path: String,
        identity: Identity,
        result: ClaudeSessionRecordScanner.Result?
    ) -> Resolution? {
        guard let result else {
            return entries[path].map {
                resolution(from: $0.result, modifiedAt: $0.identity.modifiedAt)
            }
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
