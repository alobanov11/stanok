import Foundation

struct BranchActions {

    let isOperating: Bool

    let checkDirty: () async -> Bool?

    let checkRefFormat: (String) async -> GitCommandOutcome

    let create: (String) async -> GitCommandOutcome

    let switchTo: (GitBranchRef) async -> GitCommandOutcome

    let delete: (String) async -> GitCommandOutcome

    let fetch: () -> Void

    let pull: () -> Void
}

extension BranchActions {

    @MainActor
    static func make(
        isOperating: Bool,
        repository: @escaping () -> Repository?,
        branchStore: GitBranchStore,
        afterSwitch: @escaping () async -> Void,
        fetch: @escaping () -> Void,
        pull: @escaping () -> Void
    ) -> BranchActions {
        BranchActions(
            isOperating: isOperating,
            checkDirty: {
                guard let repository = repository() else { return nil }

                let path = repository.url.path(percentEncoded: false)
                return await GitBranchOperations.isDirty(at: path)
            },
            checkRefFormat: { name in
                guard let repository = repository() else {
                    return GitCommandOutcome(succeeded: false, message: "Нет открытого репозитория")
                }

                let path = repository.url.path(percentEncoded: false)
                return await GitBranchOperations.checkRefFormat(name: name, at: path)
            },
            create: { name in
                guard let repository = repository() else {
                    return GitCommandOutcome(succeeded: false, message: "Нет открытого репозитория")
                }

                let path = repository.url.path(percentEncoded: false)
                return await branchStore.perform(for: repository) {
                    await GitBranchOperations.create(name: name, at: path)
                }
            },
            switchTo: { ref in
                guard let repository = repository() else {
                    return GitCommandOutcome(succeeded: false, message: "Нет открытого репозитория")
                }

                let path = repository.url.path(percentEncoded: false)
                let outcome = await branchStore.perform(for: repository) {
                    switch ref.kind {
                    case .local:
                        return await GitBranchOperations.switchTo(name: ref.displayName, at: path)

                    case .remote:
                        let remoteRef = String(ref.fullName.dropFirst("refs/remotes/".count))
                        return await GitBranchOperations.createTrackingAndSwitch(
                            local: ref.displayName,
                            remoteRef: remoteRef,
                            at: path
                        )
                    }
                }

                await afterSwitch()
                return outcome
            },
            delete: { name in
                guard let repository = repository() else {
                    return GitCommandOutcome(succeeded: false, message: "Нет открытого репозитория")
                }

                let path = repository.url.path(percentEncoded: false)
                return await branchStore.perform(for: repository) {
                    await GitBranchOperations.delete(name: name, at: path)
                }
            },
            fetch: fetch,
            pull: pull
        )
    }
}
