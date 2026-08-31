import Foundation

public enum GitBranchOccupancy {

    public static func apply(
        _ refs: [GitBranchRef],
        worktrees: [GitWorktreeEntry],
        currentRoot: String
    ) -> [GitBranchRef] {
        let normalizedRoot = normalize(currentRoot)
        var occupancy: [String: String] = [:]

        for worktree in worktrees {
            guard let branch = worktree.branchFullName else { continue }
            guard normalize(worktree.path) != normalizedRoot else { continue }

            occupancy[branch] = worktree.path
        }

        return refs.map { ref in
            guard let path = occupancy[ref.fullName] else { return ref }

            return ref.withOccupancy(path)
        }
    }

    private static func normalize(_ path: String) -> String {
        URL(fileURLWithPath: path).standardizedFileURL.path(percentEncoded: false)
    }
}
