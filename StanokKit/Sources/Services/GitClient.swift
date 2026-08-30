import Foundation

public enum GitClient {

    public static func status(for url: URL) async -> GitStatus? {
        let path = url.path(percentEncoded: false)
        guard let branch = await run(["-C", path, "rev-parse", "--abbrev-ref", "HEAD"])
        else { return nil }

        let shortstat = await run(["-C", path, "diff", "--shortstat"]) ?? ""
        let (added, removed) = parse(shortstat)
        return GitStatus(branch: branch.isEmpty ? nil : branch, added: added, removed: removed)
    }

    private static func parse(_ shortstat: String) -> (added: Int, removed: Int) {
        var added = 0
        var removed = 0

        if let match = shortstat.firstMatch(of: /(\d+) insertion/) { added = Int(match.1) ?? 0 }
        if let match = shortstat.firstMatch(of: /(\d+) deletion/) { removed = Int(match.1) ?? 0 }
        return (added, removed)
    }

    private static func run(_ arguments: [String]) async -> String? {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                let process = Process()
                process.executableURL = URL(filePath: "/usr/bin/env")
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
                    let text = String(decoding: data, as: UTF8.self)
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    continuation.resume(returning: text)
                } catch {
                    continuation.resume(returning: nil)
                }
            }
        }
    }
}
