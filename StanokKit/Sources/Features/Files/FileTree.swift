import AppKit
import SwiftUI

struct FileTree: View {

    var body: some View {
        content
            .onChange(of: url, initial: true) { _, new in model.open(new) }
            .alert(prompt?.title ?? "", isPresented: isPrompting) {
                TextField("Имя", text: $name)
                Button("Отмена", role: .cancel) { prompt = nil }
                Button("Готово") { commit() }
            }
            .alert("Не получилось", isPresented: isFailing) {
                Button("Ок") { failure = nil }
            } message: {
                Text(failure ?? "")
            }
    }

    let url: URL?

    let onOpen: (URL) -> Void

    @State
    private var model = FileTreeModel()

    @State
    private var selected: URL?

    @State
    private var prompt: FilePrompt?

    @State
    private var name = ""

    @State
    private var failure: String?

    private var isPrompting: Binding<Bool> {
        Binding(get: { prompt != nil }, set: { if !$0 { prompt = nil } })
    }

    private var isFailing: Binding<Bool> {
        Binding(get: { failure != nil }, set: { if !$0 { failure = nil } })
    }

    @ViewBuilder
    private var content: some View {
        if let root = model.root {
            ScrollView {
                LazyVStack(spacing: 1) {
                    ForEach(root.visibleDescendants) { row($0) }
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 10)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
            .contextMenu { rootMenu(root) }
        } else {
            placeholder
        }
    }

    private var placeholder: some View {
        VStack {
            Spacer()

            Text("Выбери проект")
                .font(Typography.caption)
                .foregroundStyle(.tertiary)

            Spacer()
        }
    }

    private func row(_ node: FileNode) -> some View {
        FileRow(node: node, isSelected: node.url == selected)
            .onTapGesture {
                selected = node.url

                guard node.isDirectory else {
                    onOpen(node.url)
                    return
                }

                withAnimation(.smooth(duration: 0.2)) { node.toggle() }
            }
            .contextMenu { menu(node) }
    }

    @ViewBuilder
    private func rootMenu(_ root: FileNode) -> some View {
        Button("Новый файл…") { ask(.newFile, at: root.url) }
        Button("Новая папка…") { ask(.newFolder, at: root.url) }
    }

    @ViewBuilder
    private func menu(_ node: FileNode) -> some View {
        Button("Новый файл…") { ask(.newFile, at: container(of: node)) }
        Button("Новая папка…") { ask(.newFolder, at: container(of: node)) }

        Divider()

        Button("Переименовать…") { ask(.rename, at: node.url) }
        Button("Показать в Finder") { NSWorkspace.shared.activateFileViewerSelecting([node.url]) }
        Button("Скопировать путь") { copyPath(node.url) }

        Divider()

        Button("Удалить", role: .destructive) { perform { try FileOperations.trash(node.url) } }
    }

    private func container(of node: FileNode) -> URL {
        node.isDirectory ? node.url : node.url.deletingLastPathComponent()
    }

    private func copyPath(_ url: URL) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(url.path(percentEncoded: false), forType: .string)
    }

    private func ask(_ kind: FilePrompt.Kind, at target: URL) {
        if case .rename = kind {
            name = target.lastPathComponent
        } else {
            name = ""
        }

        prompt = FilePrompt(kind: kind, target: target)
    }

    private func commit() {
        guard let prompt else { return }

        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        self.prompt = nil
        guard !trimmed.isEmpty else { return }

        perform {
            switch prompt.kind {
            case .newFile: try FileOperations.createFile(named: trimmed, in: prompt.target)
            case .newFolder: try FileOperations.createDirectory(named: trimmed, in: prompt.target)
            case .rename: try FileOperations.rename(prompt.target, to: trimmed)
            }
        }
    }

    private func perform(_ action: () throws -> Void) {
        do {
            try action()
        } catch {
            failure = error.localizedDescription
        }
    }
}
