import SwiftUI

struct AgentChangesPanel: View {

    @ViewBuilder
    private var content: some View {
        if model.repositories.isEmpty {
            placeholder
        } else {
            ScrollView {
                LazyVStack(spacing: 1) {
                    ForEach(model.repositories) { repository in
                        SectionHeader(title: repository.name)

                        ForEach(repository.changes, id: \.path) { change in
                            row(repository, path: change.path, status: change.status)
                        }

                        ForEach(repository.touchedOnly, id: \.url) { file in
                            row(repository, path: relative(file.url, in: repository), status: nil)
                        }
                    }
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 10)
                .frame(maxWidth: .infinity, alignment: .top)
            }
        }
    }

    private var placeholder: some View {
        VStack {
            Spacer()

            Text(model.isLoading ? "Смотрю, куда заходили агенты" : "Изменений нет")
                .font(Typography.caption)
                .foregroundStyle(.tertiary)

            Spacer()
        }
    }

    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .task { model.refresh() }
    }

    let model: AgentChangesModel

    @Binding
    var selected: URL?

    let onOpen: (URL) -> Void

    private func row(
        _ repository: AgentRepositoryChanges,
        path: String,
        status: GitFileStatus?
    ) -> some View {
        let url = URL(filePath: repository.root).appending(path: path)

        return FileRow(
            name: path,
            url: url,
            isDirectory: false,
            isExpanded: false,
            depth: 0,
            status: status,
            isSelected: url == selected,
            actions: nil
        )
        .opacity(status == nil ? 0.55 : 1)
        .onTapGesture {
            guard status != .deleted else { return }

            selected = url
            onOpen(url)
        }
    }

    private func relative(_ url: URL, in repository: AgentRepositoryChanges) -> String {
        let base = repository.root.hasSuffix("/") ? repository.root : repository.root + "/"
        let path = url.path(percentEncoded: false)
        guard path.hasPrefix(base) else { return url.lastPathComponent }

        return String(path.dropFirst(base.count))
    }
}
