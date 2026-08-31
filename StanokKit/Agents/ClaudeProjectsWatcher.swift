import Foundation
import StanokKit

@MainActor
final class ClaudeProjectsWatcher: Sendable {

    private var watcher: FileWatcher?

    private var hasStarted = false

    nonisolated init() {}

    func start(root: URL, onChange: @escaping @Sendable () -> Void) {
        guard !hasStarted else { return }

        hasStarted = true

        let fileWatcher = FileWatcher(onDirectoriesChanged: { _ in }, onGitChange: onChange)
        fileWatcher.watch(root, gitDirectory: nil)
        watcher = fileWatcher
    }
}
