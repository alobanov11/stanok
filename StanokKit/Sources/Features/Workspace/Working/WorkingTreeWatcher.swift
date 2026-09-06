import Foundation

// Почему: в режиме Git дерево файлов закрыто, и без своего наблюдателя изменения никто не видит
@MainActor
final class WorkingTreeWatcher {

    private var watcher: FileWatcher?
    private var root: URL?
    private var directories: [String] = []

    func watch(_ url: URL?, gitDirectories: [String], onChange: @escaping () -> Void) {
        guard url != root || gitDirectories != directories else { return }

        watcher?.stop()
        root = url
        directories = gitDirectories

        guard let url else {
            watcher = nil

            return
        }

        let watcher = FileWatcher(
            onDirectoriesChanged: { _ in onChange() },
            onGitChange: onChange
        )
        watcher.watch(url, gitDirectories: gitDirectories)
        self.watcher = watcher
    }

    func stop() {
        watcher?.stop()
        watcher = nil
        root = nil
        directories = []
    }
}
