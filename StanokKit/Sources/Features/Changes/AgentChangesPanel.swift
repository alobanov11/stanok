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

                        ForEach(visible(repository, folders: folders), id: \.url) { node in
                            row(repository, node: node, folders: folders)
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
            .onAppear { chosen = selected }
            .onChange(of: selected) { _, url in
                if url != chosen { chosen = url }
            }
    }

    let model: AgentChangesModel

    @Binding
    var selected: URL?

    @State
    private var chosen: URL?

    @AppStorage("agentChanges.expandedFolders")
    private var expandedRaw = ""

    let onOpen: (URL) -> Void

    private var folders: Set<String> {
        Set(expandedRaw.split(separator: "\n").map(String.init))
    }

    private func visible(
        _ repository: AgentRepositoryChanges,
        folders: Set<String>
    ) -> [GitTreeNode] {
        var rows: [GitTreeNode] = []

        func append(_ node: GitTreeNode) {
            rows.append(node)
            guard node.isDirectory, folders.contains(key(repository, node)) else { return }

            for child in node.children {
                append(child)
            }
        }

        for node in repository.nodes {
            append(node)
        }

        return rows
    }

    private func key(_ repository: AgentRepositoryChanges, _ node: GitTreeNode) -> String {
        repository.root + "|" + node.relativePath
    }

    private func row(
        _ repository: AgentRepositoryChanges,
        node: GitTreeNode,
        folders: Set<String>
    ) -> some View {
        FileRow(
            name: node.name,
            url: node.url,
            isDirectory: node.isDirectory,
            isExpanded: folders.contains(key(repository, node)),
            depth: node.depth - 1,
            status: node.status,
            isSelected: node.url == chosen,
            actions: nil
        )
        .opacity(node.status == nil ? 0.55 : 1)
        .onTapGesture { select(repository, node: node) }
    }

    private func select(_ repository: AgentRepositoryChanges, node: GitTreeNode) {
        guard !node.isDirectory else {
            var opened = folders
            let key = key(repository, node)
            if opened.contains(key) { opened.remove(key) } else { opened.insert(key) }
            expandedRaw = opened.sorted().joined(separator: "\n")
            return
        }

        guard node.status != .deleted else { return }

        chosen = node.url
        selected = node.url
        onOpen(node.url)
    }
}
