import Foundation

enum GitBranchClient {

    static func root(at path: String) async -> String? {
        let result = await GitProcessRunner.run(["-C", path, "rev-parse", "--show-toplevel"])
        guard result.exitCode == 0 else { return nil }

        let root = (String(data: result.standardOutput, encoding: .utf8) ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return root.isEmpty ? nil : root
    }

    static func snapshot(
        refs refsOutcome: GitProcessRunner.Result,
        worktrees worktreeOutcome: GitProcessRunner.Result,
        root: String
    ) -> GitBranchSnapshot {
        let refs = refsOutcome.exitCode == 0
            ? GitBranchRefParser.parse(refsOutcome.standardOutput)
            : []
        let worktrees = worktreeOutcome.exitCode == 0
            ? GitWorktreeListParser.parse(worktreeOutcome.standardOutput)
            : []

        return GitBranchSnapshot(
            refs: GitBranchOccupancy.apply(refs, worktrees: worktrees, currentRoot: root),
            root: root,
            listError: refsOutcome.exitCode == 0 ? nil : refsOutcome.standardError,
            worktreeError: worktreeOutcome.exitCode == 0 ? nil : worktreeOutcome.standardError
        )
    }

    static func listBranches(for url: URL) async -> GitBranchSnapshot {
        let path = url.path(percentEncoded: false)

        guard let root = await root(at: path) else { return GitBranchSnapshot(refs: []) }

        async let refsResult = GitProcessRunner.run([
            "--no-optional-locks", "-C", path, "for-each-ref",
            "--format=%(refname)%00%(symref)%00%(HEAD)", "refs/heads/", "refs/remotes/"
        ])
        async let worktreeResult = GitProcessRunner.run([
            "-C", path, "worktree", "list", "--porcelain", "-z"
        ])

        return await snapshot(refs: refsResult, worktrees: worktreeResult, root: root)
    }
}
