import Foundation

@MainActor
@Observable
final class FileTreeModel {

    private(set) var root: FileNode?

    private var watcher: FileWatcher?

    func open(_ url: URL?) {
        guard root?.url != url else { return }

        watcher?.stop()
        watcher = nil

        guard let url else {
            root = nil
            return
        }

        let node = FileNode(url: url, isDirectory: true, depth: 0)
        node.expand()
        root = node

        let watcher = FileWatcher { [weak self] directories in
            self?.apply(directories)
        }
        watcher.watch(url)
        self.watcher = watcher
    }

    private func apply(_ directories: Set<URL>) {
        guard let root else { return }

        for directory in directories {
            root.node(at: directory)?.reload()
        }
    }
}
