import Foundation

public enum ReviewFiles {

    // Почему: правки рабочего дерева и каждый коммит читают отдельными группами
    public static func build(
        root: String,
        changes: [GitChange],
        commits: [GitCommitChanges],
        repository: String?
    ) -> [ReviewFile] {
        let base = URL(filePath: root)
        let prefix = repository.map { $0 + " · " } ?? ""

        let pending = changes.map {
            ReviewFile(
                url: base.appending(path: $0.path),
                path: $0.path,
                status: $0.status,
                root: root,
                groupName: prefix + "Не закоммичено",
                source: .worktree
            )
        }

        let committed = commits.flatMap { commit in
            commit.changes.map {
                ReviewFile(
                    url: base.appending(path: $0.path),
                    path: $0.path,
                    status: $0.status,
                    root: root,
                    groupName: prefix + commit.title,
                    source: .commit(commit.sha)
                )
            }
        }

        return pending + committed
    }
}
