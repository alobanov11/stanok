import Foundation

struct BranchActions {

    let isOperating: Bool
    let checkDirty: () async -> GitWorkingTree
    let checkRefFormat: (String) async -> GitCommandOutcome
    let create: (String) async -> GitCommandOutcome
    let switchTo: (GitBranchRef) async -> GitCommandOutcome
    let delete: (String) async -> GitCommandOutcome
    let fetch: () -> Void
    let pull: () -> Void
}

extension BranchActions {

    @MainActor
    static func guarded<Input: Sendable>(
        _ session: @escaping () -> TerminalSession?,
        _ work: @escaping (Input, TerminalSession, String) async -> GitCommandOutcome
    ) -> (Input) async -> GitCommandOutcome {
        { input in
            guard let session = session() else {
                return GitCommandOutcome(succeeded: false, message: "Нет открытого репозитория")
            }

            return await work(input, session, session.url.path(percentEncoded: false))
        }
    }

    @MainActor
    static func switchBranch(
        _ ref: GitBranchRef,
        session: TerminalSession,
        path: String,
        branchStore: GitBranchStore,
        afterSwitch: @escaping (TerminalSession.ID) async -> Void
    ) async -> GitCommandOutcome {
        let outcome = await branchStore.perform(for: session) {
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

        if outcome.succeeded { await afterSwitch(session.id) }

        return outcome
    }

    @MainActor
    static func make(
        isOperating: Bool,
        session: @escaping () -> TerminalSession?,
        branchStore: GitBranchStore,
        afterSwitch: @escaping (TerminalSession.ID) async -> Void,
        fetch: @escaping () -> Void,
        pull: @escaping () -> Void
    ) -> BranchActions {
        BranchActions(
            isOperating: isOperating,
            checkDirty: {
                guard let session = session() else { return .unknown }

                return await GitBranchOperations.workingTree(
                    at: session.url.path(percentEncoded: false)
                )
            },
            checkRefFormat: guarded(session) { name, _, path in
                await GitBranchOperations.checkRefFormat(name: name, at: path)
            },
            create: guarded(session) { name, session, path in
                await branchStore.perform(for: session) {
                    await GitBranchOperations.create(name: name, at: path)
                }
            },
            switchTo: guarded(session) { ref, session, path in
                await switchBranch(
                    ref,
                    session: session,
                    path: path,
                    branchStore: branchStore,
                    afterSwitch: afterSwitch
                )
            },
            delete: guarded(session) { name, session, path in
                await branchStore.perform(for: session) {
                    await GitBranchOperations.delete(name: name, at: path)
                }
            },
            fetch: fetch,
            pull: pull
        )
    }
}
