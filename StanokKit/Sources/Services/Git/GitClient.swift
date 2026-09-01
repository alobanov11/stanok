import Foundation

public enum GitClient {

    public enum Probe: Sendable {

        case notRepository
        case failed
        case snapshot(GitSnapshot)
    }

    private enum Limit {

        static let untrackedFileSize = 1_000_000
        static let untrackedEntryCap = 2000
        static let binarySniffSize = 8192
        static let reviewedCommits = 20
    }

    public static func status(for url: URL) async -> GitStatus? {
        guard case let .snapshot(snapshot) = await probe(for: url) else { return nil }

        return GitStatus(
            branch: snapshot.branch,
            added: snapshot.added,
            removed: snapshot.removed,
            isDirty: !snapshot.changes.isEmpty,
            tracking: snapshot.tracking
        )
    }

    public static func root(for url: URL) async -> String? {
        let path = url.path(percentEncoded: false)
        guard let root = await run(["rev-parse", "--show-toplevel"], at: path), !root.isEmpty
        else { return nil }

        return root
    }

    public static func changes(at url: URL) async -> [GitChange] {
        await workingChanges(at: url) ?? []
    }

    // Почему: сбой git — не «изменений нет», такой ответ нельзя показывать и кэшировать
    public static func workingChanges(at url: URL) async -> [GitChange]? {
        let path = url.path(percentEncoded: false)
        guard let data = await runRaw(["status", "--porcelain=v2", "-z", "-uall"], at: path)
        else { return nil }

        return GitStatusParser.parse(data)
    }

    public static func head(at url: URL) async -> String? {
        let path = url.path(percentEncoded: false)
        guard let sha = await run(["rev-parse", "HEAD"], at: path), !sha.isEmpty
        else { return nil }

        return sha
    }

    public static func parent(at url: URL) async -> String? {
        let path = url.path(percentEncoded: false)
        guard let sha = await run(["rev-parse", "HEAD^"], at: path), !sha.isEmpty else { return nil }

        return sha
    }

    // Почему: правку читают и после коммита, поэтому показываем всё с точки отсчёта
    public static func history(
        of ref: String,
        at url: URL,
        limit: Int
    ) async -> [GitCommitChanges]? {
        await log(range: ref, at: url, limit: limit)
    }

    public static func commits(
        since base: String,
        upTo head: String,
        at url: URL
    ) async -> [GitCommitChanges]? {
        await log(range: "\(base)..\(head)", at: url, limit: Limit.reviewedCommits)
    }

    static func log(range: String, at url: URL, limit: Int) async -> [GitCommitChanges]? {
        let path = url.path(percentEncoded: false)
        let arguments = [
            "log", "--name-status", "-z", "-M", "--first-parent", "--root",
            "--max-count=\(limit)",
            "--format=%x1e%H%x1f%s%x1f", range
        ]

        guard let log = await runRaw(arguments, at: path) else { return nil }

        return GitCommitParser.commits(log)
    }

    public static func probe(for url: URL) async -> Probe {
        let path = url.path(percentEncoded: false)

        guard let root = await run(["rev-parse", "--show-toplevel"], at: path), !root.isEmpty
        else { return .notRepository }

        guard let gitDirectory = await run(["rev-parse", "--absolute-git-dir"], at: path)
        else { return .failed }

        guard let statusData = await runRaw(["status", "--porcelain=v2", "-z", "-uall"], at: path)
        else { return .failed }

        return await .snapshot(snapshot(
            at: path,
            root: root,
            gitDirectory: gitDirectory,
            statusData: statusData
        ))
    }
}

private extension GitClient {

    static func snapshot(
        at path: String,
        root: String,
        gitDirectory: String,
        statusData: Data
    ) async -> GitSnapshot {
        let commonDirectory = await run(
            ["rev-parse", "--path-format=absolute", "--git-common-dir"],
            at: path
        )

        let branch = await run(["branch", "--show-current"], at: path) ?? ""
        let hasCommit = await run(["rev-parse", "--verify", "HEAD"], at: path) != nil
        let diffArguments = hasCommit
            ? ["diff", "HEAD", "--numstat", "-z", "--ignore-submodules=all"]
            : ["diff", "--cached", "--numstat", "-z", "--ignore-submodules=all"]

        let numstat = await run(diffArguments, at: path) ?? ""
        let (diffAdded, removed) = parseNumstat(numstat)
        let untracked = untrackedAddedLines(in: statusData, root: URL(filePath: root))
        let tracking = await GitTracking.parse(
            run(["rev-list", "--left-right", "--count", "HEAD...@{upstream}"], at: path)
        )

        return GitSnapshot(
            branch: branch.isEmpty ? nil : branch,
            isDetached: branch.isEmpty,
            root: root,
            gitDirectory: gitDirectory,
            commonDirectory: commonDirectory,
            added: diffAdded + untracked,
            removed: removed,
            changes: GitStatusParser.parse(statusData),
            tracking: tracking
        )
    }

    static func parseNumstat(_ raw: String) -> (added: Int, removed: Int) {
        let chunks = raw.split(separator: "\0", omittingEmptySubsequences: false)
        var total = (added: 0, removed: 0)
        var index = 0

        while index < chunks.count {
            let chunk = chunks[index]
            index += 1

            guard let entry = numstatEntry(chunk) else { continue }

            total.added += entry.added
            total.removed += entry.removed
            index += entry.skip
        }

        return total
    }

    static func numstatEntry(_ chunk: Substring) -> (added: Int, removed: Int, skip: Int)? {
        guard !chunk.isEmpty else { return nil }

        let fields = chunk.split(separator: "\t", omittingEmptySubsequences: false)
        guard fields.count >= 2 else { return nil }

        // Почему: у переименования третье поле пустое, а следом идут две части старого пути
        let skip = fields.count == 3 && fields[2].isEmpty ? 2 : 0
        guard fields[0] != "-", fields[1] != "-" else { return (0, 0, skip) }

        return (Int(fields[0]) ?? 0, Int(fields[1]) ?? 0, skip)
    }

    static func untrackedAddedLines(in data: Data?, root: URL) -> Int {
        let output = data.flatMap { String(data: $0, encoding: .utf8) } ?? ""
        let paths = output
            .split(separator: "\0", omittingEmptySubsequences: true)
            .compactMap { entry in entry.hasPrefix("? ") ? String(entry.dropFirst(2)) : nil }

        guard paths.count <= Limit.untrackedEntryCap else { return 0 }

        return paths.reduce(0) { $0 + lineCount(at: root.appending(path: $1)) }
    }

    static func readableHandle(at url: URL) -> FileHandle? {
        let values = try? url.resourceValues(forKeys: [.fileSizeKey])
        guard let size = values?.fileSize, size > 0, size <= Limit.untrackedFileSize else {
            return nil
        }

        return try? FileHandle(forReadingFrom: url)
    }

    static func lineCount(at url: URL) -> Int {
        guard let handle = readableHandle(at: url) else { return 0 }

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
        let environment = ToolEnvironment.current

        return await withCheckedContinuation { continuation in
            GitProcessQueue.serial.async {
                let process = Process()
                process.executableURL = URL(filePath: "/usr/bin/env")
                process.environment = environment
                process.standardInput = FileHandle.nullDevice
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
