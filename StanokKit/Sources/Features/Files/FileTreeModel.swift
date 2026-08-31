import Foundation

@MainActor
@Observable
final class FileTreeModel {

    private(set) var root: FileNode?

    private var watcher: FileWatcher?

    private var onGitChange: (() -> Void)?

    private var currentGitDirectory: String?

    func open(_ url: URL?, gitDirectory: String?, onGitChange: @escaping () -> Void) {
        self.onGitChange = onGitChange

        guard root?.url != url else { return }

        watcher?.stop()
        watcher = nil
        currentGitDirectory = nil

        guard let url else {
            root = nil
            return
        }

        let node = FileNode(url: url, isDirectory: true, depth: 0, relativePath: "")
        node.expand()
        root = node

        startWatcher(at: url, gitDirectory: gitDirectory)
    }

    func updateGitDirectory(_ gitDirectory: String?) {
        guard let root, gitDirectory != currentGitDirectory else { return }

        startWatcher(at: root.url, gitDirectory: gitDirectory)
    }

    private func startWatcher(at url: URL, gitDirectory: String?) {
        currentGitDirectory = gitDirectory

        let watcher = FileWatcher(
            onDirectoriesChanged: { [weak self] directories in self?.apply(directories) },
            onGitChange: { [weak self] in self?.onGitChange?() }
        )
        watcher.watch(url, gitDirectory: gitDirectory)
        self.watcher = watcher
    }

    private func apply(_ directories: Set<URL>) {
        guard let root else { return }

        for directory in directories {
            root.node(at: directory)?.reload()
        }
    }
}
