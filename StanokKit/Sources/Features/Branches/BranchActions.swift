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
