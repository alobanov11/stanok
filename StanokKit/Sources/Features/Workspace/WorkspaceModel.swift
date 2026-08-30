import Foundation

@MainActor
@Observable
final class WorkspaceModel {

    private(set) var runs: [CommandRun] = []

    func record(_ run: CommandRun) {
        runs.insert(run, at: 0)
        if runs.count > 200 {
            runs.removeLast(runs.count - 200)
        }
    }
}
