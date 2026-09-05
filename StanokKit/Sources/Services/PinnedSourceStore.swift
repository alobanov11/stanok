import Foundation

// Почему: инспектор показывает чужие проекты только по явному выбору пользователя
@MainActor
@Observable
public final class PinnedSourceStore {

    private struct Contents: Codable {

        var sources: [PinnedSource] = []
        var folders: [PinnedSource] = []
        var repositories: [PinnedSource] = []
    }

    // Почему: файлы и git смотрят на один список, поэтому добавленное видно в обеих вкладках
    public private(set) var sources: [PinnedSource] = []

    private let file: URL

    public init(file: URL = AppPaths.pinned) {
        self.file = file
        load()
    }

    public func add(_ url: URL) {
        let path = url.standardizedFileURL.path(percentEncoded: false)
        guard !sources.contains(where: { $0.path == path }) else { return }

        sources.append(PinnedSource(path: path))
        save()
    }

    public func remove(_ id: PinnedSource.ID) {
        sources = sources.filter { $0.id != id }
        save()
    }
}

private extension PinnedSourceStore {

    func load() {
        guard
            let data = try? Data(contentsOf: file),
            let contents = try? JSONDecoder().decode(Contents.self, from: data)
        else { return }

        // Почему: старая запись держала папки и репозитории врозь, теперь это один список
        var merged: [PinnedSource] = []

        for source in contents.sources + contents.folders + contents.repositories
            where !merged.contains(where: { $0.path == source.path }) {
            merged.append(source)
        }

        sources = merged
    }

    func save() {
        guard let data = try? JSONEncoder().encode(Contents(sources: sources)) else { return }

        try? FileManager.default.createDirectory(
            at: file.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try? data.write(to: file, options: .atomic)
    }
}
