import Foundation

enum GitWorkingTreeOperations {

    static func run(_ action: WorkingTreeAction, at root: String) async -> GitCommandOutcome {
        switch action {
        case .stash:
            let stamp = Date().formatted(date: .abbreviated, time: .shortened)
            return await stash(at: root, message: "stanok \(stamp)")

        case .discard:
            return await discard(at: root)
        }
    }

    static func discard(at root: String) async -> GitCommandOutcome {
        await outcome(["-C", root, "restore", "--staged", "--worktree", "--", "."])
    }

    static func stash(at root: String, message: String) async -> GitCommandOutcome {
        await outcome(["-C", root, "stash", "push", "--include-untracked", "-m", message])
    }

    private static func outcome(_ arguments: [String]) async -> GitCommandOutcome {
        let result = await GitProcessRunner.run(arguments)

        return GitCommandOutcome.make(
            exitCode: result.exitCode,
            standardOutput: result.standardOutput,
            standardError: result.standardError
        )
    }
}
