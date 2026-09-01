import Foundation

@MainActor
@Observable
final class InspectorState {

    private var fileTrees: [String: FileTreeModel] = [:]
    private var changeTrees: [String: ChangeTreeModel] = [:]
    private var branchTrees: [String: BranchTreeModel] = [:]
    private var selectedFiles: [String: URL] = [:]

    static func key(for folder: URL) -> String {
        let path = folder.standardizedFileURL.path(percentEncoded: false)
        guard path.count > 1, path.hasSuffix("/") else { return path }

        return String(path.dropLast())
    }

    func fileTree(for folder: URL) -> FileTreeModel {
        let key = Self.key(for: folder)
        if let existing = fileTrees[key] { return existing }

        let model = FileTreeModel()
        fileTrees[key] = model
        return model
    }

    func changeTree(for gitRoot: String) -> ChangeTreeModel {
        if let existing = changeTrees[gitRoot] { return existing }

        let model = ChangeTreeModel()
        changeTrees[gitRoot] = model
        return model
    }

    func branchTree(for gitRoot: String) -> BranchTreeModel {
        if let existing = branchTrees[gitRoot] { return existing }

        let model = BranchTreeModel()
        branchTrees[gitRoot] = model
        return model
    }

    func selectedFile(in folder: URL) -> URL? {
        selectedFiles[Self.key(for: folder)]
    }

    func select(_ url: URL?, in folder: URL) {
        selectedFiles[Self.key(for: folder)] = url
    }

    // Почему: невидимое дерево продолжало держать FSEvents и обновляться впустую
    func closeTrees() {
        for model in fileTrees.values {
            model.close()
        }
    }

    func prune(folders: Set<URL>, gitRoots: Set<String>) {
        let keys = Set(folders.map { Self.key(for: $0) })

        for (key, model) in fileTrees where !keys.contains(key) {
            model.close()
            fileTrees[key] = nil
        }

        selectedFiles = selectedFiles.filter { keys.contains($0.key) }
        changeTrees = changeTrees.filter { gitRoots.contains($0.key) }
        branchTrees = branchTrees.filter { gitRoots.contains($0.key) }
    }
}
