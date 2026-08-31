import Foundation

enum GitBranchClient {

    static func listBranches(for url: URL) async -> GitBranchSnapshot {
        let path = url.path(percentEncoded: false)

        let rootResult = await GitProcessRunner.run(["-C", path, "rev-parse", "--show-toplevel"])
        guard rootResult.exitCode == 0 else { return GitBranchSnapshot(refs: []) }

        let root = (String(data: rootResult.standardOutput, encoding: .utf8) ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !root.isEmpty else { return GitBranchSnapshot(refs: []) }

        async let refsResult = GitProcessRunner.run([
            "--no-optional-locks", "-C", path, "for-each-ref",
            "--format=%(refname)%00%(symref)%00%(HEAD)", "refs/heads/", "refs/remotes/"
        ])
        async let worktreeResult = GitProcessRunner.run([
            "-C", path, "worktree", "list", "--porcelain", "-z"
        ])

        let refsOutcome = await refsResult
        let worktreeOutcome = await worktreeResult

        let refs = refsOutcome.exitCode == 0
            ? GitBranchRefParser.parse(refsOutcome.standardOutput)
            : []
        let worktrees = worktreeOutcome.exitCode == 0
            ? GitWorktreeListParser.parse(worktreeOutcome.standardOutput)
            : []

        let merged = GitBranchOccupancy.apply(refs, worktrees: worktrees, currentRoot: root)

        return GitBranchSnapshot(
            refs: merged,
            root: root,
            listError: refsOutcome.exitCode == 0 ? nil : refsOutcome.standardError,
            worktreeError: worktreeOutcome.exitCode == 0 ? nil : worktreeOutcome.standardError
        )
    }
}
