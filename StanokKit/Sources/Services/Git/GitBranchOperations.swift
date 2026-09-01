import Foundation

enum GitBranchOperations {

    static func checkRefFormat(name: String, at root: String) async -> GitCommandOutcome {
        await outcome(["-C", root, "check-ref-format", "--branch", name])
    }

    static func create(name: String, at root: String) async -> GitCommandOutcome {
        await outcome(["-C", root, "branch", "--", name, "HEAD"])
    }

    static func switchTo(name: String, at root: String) async -> GitCommandOutcome {
        await outcome(["-C", root, "switch", "--no-guess", name])
    }

    static func createTrackingAndSwitch(
        local: String,
        remoteRef: String,
        at root: String
    ) async -> GitCommandOutcome {
        await outcome(["-C", root, "switch", "-c", local, "--track", remoteRef])
    }

    static func delete(name: String, at root: String) async -> GitCommandOutcome {
        await outcome(["-C", root, "branch", "-d", "--", name])
    }

    static func workingTree(at root: String) async -> GitWorkingTree {
        let result = await GitProcessRunner.run([
            "--no-optional-locks", "-C", root, "status",
            "--porcelain=v2", "-z", "--untracked-files=normal"
        ])
        guard result.exitCode == 0 else { return .unknown }

        return GitStatusParser.parse(result.standardOutput).isEmpty ? .clean : .dirty
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
