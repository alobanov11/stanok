import Foundation
import StanokKit

@MainActor
final class ClaudeProjectsWatcher: Sendable {

    private var watcher: FileWatcher?
    private var hasStarted = false

    nonisolated init() {}

    @discardableResult
    func start(root: URL, onChange: @escaping @Sendable () -> Void) -> Bool {
        guard !hasStarted else { return true }

        let fileWatcher = FileWatcher(onDirectoriesChanged: { _ in }, onGitChange: onChange)
        guard fileWatcher.watch(root, gitDirectory: nil) else { return false }

        watcher = fileWatcher
        hasStarted = true
        return true
    }
}
