import Foundation

@MainActor
@Observable
final class FileTreeModel {

    private(set) var root: FileNode?
    private(set) var isUnavailable = false

    private var watcher: FileWatcher?
    private var onGitChange: (() -> Void)?
    private var currentGitDirectories: [String] = []

    func open(_ url: URL?, gitDirectories: [String], onGitChange: @escaping () -> Void) {
        self.onGitChange = onGitChange

        guard root?.url != url else { return }

        watcher?.stop()
        watcher = nil
        currentGitDirectories = []

        guard let url else {
            root = nil
            isUnavailable = false
            return
        }

        guard FileManager.default.fileExists(atPath: url.path(percentEncoded: false)) else {
            root = nil
            isUnavailable = true
            return
        }

        isUnavailable = false
        let node = FileNode(url: url, isDirectory: true, depth: 0, relativePath: "")
        node.expand()
        root = node

        startWatcher(at: url, gitDirectories: gitDirectories)
    }

    func close() {
        watcher?.stop()
        watcher = nil
        currentGitDirectories = []
        onGitChange = nil
        root = nil
    }

    func updateGitDirectories(_ gitDirectories: [String]) {
        guard let root, gitDirectories != currentGitDirectories else { return }

        startWatcher(at: root.url, gitDirectories: gitDirectories)
    }

    func reloadAll() {
        guard let root else { return }

        reload(root)
    }
}

private extension FileTreeModel {

    func reload(_ node: FileNode) {
        guard node.isDirectory, node.children != nil else { return }

        node.reload()

        for child in node.children ?? [] {
            reload(child)
        }
    }

    func startWatcher(at url: URL, gitDirectories: [String]) {
        currentGitDirectories = gitDirectories
        watcher?.stop()

        let watcher = FileWatcher(
            onDirectoriesChanged: { [weak self] directories in self?.apply(directories) },
            onGitChange: { [weak self] in self?.onGitChange?() }
        )
        watcher.watch(url, gitDirectories: gitDirectories)
        self.watcher = watcher
    }

    func apply(_ directories: Set<URL>) {
        guard let root else { return }

        for directory in directories {
            root.node(at: directory)?.reload()
        }
    }
}
