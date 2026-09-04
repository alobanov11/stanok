import Foundation

// Почему: инспектор показывает чужие проекты только по явному выбору пользователя
@MainActor
@Observable
public final class PinnedSourceStore {

    private struct Contents: Codable {

        var folders: [PinnedSource] = []
        var repositories: [PinnedSource] = []
    }

    public private(set) var folders: [PinnedSource] = []

    public private(set) var repositories: [PinnedSource] = []

    private let file: URL

    public init(file: URL = AppPaths.pinned) {
        self.file = file
        load()
    }

    public func addFolder(_ url: URL) {
        add(url, to: &folders)
    }

    public func addRepository(_ url: URL) {
        add(url, to: &repositories)
    }

    public func remove(_ id: PinnedSource.ID) {
        folders.removeAll { $0.id == id }
        repositories.removeAll { $0.id == id }
        save()
    }
}

private extension PinnedSourceStore {

    func add(_ url: URL, to list: inout [PinnedSource]) {
        let path = url.standardizedFileURL.path(percentEncoded: false)
        guard !list.contains(where: { $0.path == path }) else { return }

        list.append(PinnedSource(path: path))
        save()
    }

    func load() {
        guard
            let data = try? Data(contentsOf: file),
            let contents = try? JSONDecoder().decode(Contents.self, from: data)
        else { return }

        folders = contents.folders
        repositories = contents.repositories
    }

    func save() {
        let contents = Contents(folders: folders, repositories: repositories)
        guard let data = try? JSONEncoder().encode(contents) else { return }

        try? FileManager.default.createDirectory(
            at: file.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try? data.write(to: file, options: .atomic)
    }
}
