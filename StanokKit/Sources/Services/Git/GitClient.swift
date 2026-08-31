import Foundation

public enum GitClient {

    private enum Limit {

        static let untrackedFileSize = 1_000_000
        static let untrackedEntryCap = 2000
        static let binarySniffSize = 8192
    }

    public static func status(for url: URL) async -> GitStatus? {
        guard let snapshot = await snapshot(for: url) else { return nil }

        return GitStatus(
            branch: snapshot.branch,
            added: snapshot.added,
            removed: snapshot.removed,
            tracking: snapshot.tracking
        )
    }

    public static func snapshot(for url: URL) async -> GitSnapshot? {
        let path = url.path(percentEncoded: false)

        guard let root = await run(["rev-parse", "--show-toplevel"], at: path), !root.isEmpty
        else { return nil }

        guard let gitDirectory = await run(["rev-parse", "--absolute-git-dir"], at: path)
        else { return nil }

        let branch = await run(["branch", "--show-current"], at: path) ?? ""
        let hasCommit = await run(["rev-parse", "--verify", "HEAD"], at: path) != nil
        let diffArguments = hasCommit
            ? ["diff", "HEAD", "--numstat", "-z", "--ignore-submodules=all"]
            : ["diff", "--cached", "--numstat", "-z", "--ignore-submodules=all"]

        let numstat = await run(diffArguments, at: path) ?? ""
        let (diffAdded, removed) = parseNumstat(numstat)
        let untracked = await untrackedAddedLines(at: path, root: url)

        let statusData = await runRaw(["status", "--porcelain=v2", "-z", "-uall"], at: path)
        let tracking = await GitTracking.parse(
            run(["rev-list", "--left-right", "--count", "HEAD...@{upstream}"], at: path)
        )

        return GitSnapshot(
            branch: branch.isEmpty ? nil : branch,
            isDetached: branch.isEmpty,
            root: root,
            gitDirectory: gitDirectory,
            added: diffAdded + untracked,
            removed: removed,
            changes: GitStatusParser.parse(statusData ?? Data()),
            tracking: tracking
        )
    }
}

private extension GitClient {

    static func parseNumstat(_ raw: String) -> (added: Int, removed: Int) {
        let chunks = raw.split(separator: "\0", omittingEmptySubsequences: false)
        var added = 0
        var removed = 0
        var index = 0

        while index < chunks.count {
            let chunk = chunks[index]
            index += 1
            guard !chunk.isEmpty else { continue }

            let fields = chunk.split(separator: "\t", omittingEmptySubsequences: false)
            guard fields.count >= 2 else { continue }

            if fields[0] != "-", fields[1] != "-" {
                added += Int(fields[0]) ?? 0
                removed += Int(fields[1]) ?? 0
            }

            if fields.count == 3, fields[2].isEmpty { index += 2 }
        }

        return (added, removed)
    }

    static func untrackedAddedLines(at path: String, root: URL) async -> Int {
        let output = await run(["status", "--porcelain=v2", "-z", "-uall"], at: path) ?? ""
        let paths = output
            .split(separator: "\0", omittingEmptySubsequences: true)
            .compactMap { entry in entry.hasPrefix("? ") ? String(entry.dropFirst(2)) : nil }

        guard paths.count <= Limit.untrackedEntryCap else { return 0 }

        return paths.reduce(0) { $0 + lineCount(at: root.appending(path: $1)) }
    }

    static func lineCount(at url: URL) -> Int {
        let values = try? url.resourceValues(forKeys: [.fileSizeKey])
        guard let size = values?.fileSize, size > 0, size <= Limit.untrackedFileSize else {
            return 0
        }

        guard let handle = try? FileHandle(forReadingFrom: url) else { return 0 }

        defer { try? handle.close() }

        guard let head = try? handle.read(upToCount: Limit.binarySniffSize), !head.contains(0)
        else { return 0 }

        let tail = (try? handle.readToEnd()) ?? Data()
        let headLines = head.lazy.count(where: { $0 == 0x0A })
        let tailLines = tail.lazy.count(where: { $0 == 0x0A })
        let lastByte = tail.last ?? head.last

        return lastByte == 0x0A ? headLines + tailLines : headLines + tailLines + 1
    }

    static func run(_ arguments: [String], at path: String) async -> String? {
        await run(["--no-optional-locks", "-C", path] + arguments)
    }

    static func run(_ arguments: [String]) async -> String? {
        guard let data = await runRaw(arguments), let text = String(data: data, encoding: .utf8)
        else { return nil }

        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func runRaw(_ arguments: [String], at path: String) async -> Data? {
        await runRaw(["--no-optional-locks", "-C", path] + arguments)
    }

    static func runRaw(_ arguments: [String]) async -> Data? {
        await withCheckedContinuation { continuation in
            GitProcessQueue.serial.async {
                let process = Process()
                process.executableURL = URL(filePath: "/usr/bin/env")
                process.environment = ToolEnvironment.current
                process.arguments = ["git"] + arguments

                let pipe = Pipe()
                process.standardOutput = pipe
                process.standardError = FileHandle.nullDevice

                do {
                    try process.run()
                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    process.waitUntilExit()
                    guard process.terminationStatus == 0 else {
                        continuation.resume(returning: nil)
                        return
                    }
                    continuation.resume(returning: data)
                } catch {
                    continuation.resume(returning: nil)
                }
            }
        }
    }
}
