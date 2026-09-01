import AppKit
import SwiftUI

struct FileTree: View {

    var body: some View {
        content
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

    @ViewBuilder
    private var content: some View {
        if let root = model.root {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 1) {
                        ForEach(root.visibleDescendants) { row($0) }
                    }
                    .padding(.horizontal, 8)
                    .padding(.bottom, 10)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                }
                .contextMenu { rootMenu(root) }
                .onChange(of: selected) { _, target in reveal(target, in: root, proxy: proxy) }
                .task { reveal(selected, in: root, proxy: proxy) }
                .dragContainer(for: URL.self, itemID: \.self, in: dragNamespace) { $0 }
                .dragConfiguration(dragConfiguration)
            }
        } else {
            placeholder
        }
    }

    private var placeholder: some View {
        VStack {
            Spacer()

            Text(model.isUnavailable ? "Директория недоступна" : "Выбери проект")
                .font(Typography.caption)
                .foregroundStyle(.tertiary)

            Spacer()
        }
    }

    private var isPrompting: Binding<Bool> {
        Binding(get: { prompt != nil }, set: { if !$0 { prompt = nil } })
    }

    private var isFailing: Binding<Bool> {
        Binding(get: { failure != nil }, set: { if !$0 { failure = nil } })
    }

    private var dragConfiguration: DragConfiguration {
        DragConfiguration(
            operationsWithinApp: .init(allowCopy: true, allowMove: true, allowDelete: false),
            operationsOutsideApp: .init(allowCopy: true, allowMove: false, allowDelete: false)
        )
    }

    let model: FileTreeModel
    let snapshot: GitSnapshot?

    @Binding
    var selected: URL?

    let onOpen: (URL) -> Void

    @Namespace
    private var dragNamespace

    @State
    private var prompt: FilePrompt?

    @State
    private var name = ""

    @State
    private var failure: String?

    @State
    private var dropTarget: URL?

    @State
    private var expandTarget: URL?

    @State
    private var expandTask: Task<Void, Never>?
}

private extension FileTree {

    func status(for node: FileNode) -> GitFileStatus? {
        guard let snapshot else { return nil }

        if node.isDirectory {
            return snapshot.dirtyDirectories.contains(node.relativePath) ? .modified : nil
        }

        return snapshot.byPath[node.relativePath]
    }

    func row(_ node: FileNode) -> some View {
        FileRow(
            name: node.name,
            url: node.url,
            isDirectory: node.isDirectory,
            isExpanded: node.isExpanded,
            depth: node.depth,
            status: status(for: node),
            isSelected: node.url == selected,
            isDropTarget: node.url == dropTarget,
            actions: FileRow.Actions(items: [
                .init(
                    icon: "doc.badge.plus",
                    hint: "Новый файл",
                    action: { ask(.newFile, at: container(of: node)) }
                ),
                .init(
                    icon: "pencil",
                    hint: "Переименовать",
                    action: { ask(.rename, at: node.url) }
                ),
                .init(
                    icon: "trash",
                    hint: "Удалить",
                    action: { perform { try FileOperations.trash(node.url) } }
                )
            ])
        )
        .onTapGesture {
            selected = node.url

            guard node.isDirectory else {
                onOpen(node.url)
                return
            }

            withAnimation(.smooth(duration: 0.2)) { node.toggle() }
        }
        .contextMenu { menu(node) }
        .draggable(containerItemID: node.url, containerNamespace: dragNamespace)
        .dropDestination(for: URL.self, isEnabled: true) { items, session in
            handleDrop(items, onto: node, session: session)
        }
        .dropConfiguration { session in dropConfiguration(for: node, session: session) }
        .onDropSessionUpdated { session in sessionUpdated(session, for: node) }
    }

    func dropConfiguration(for node: FileNode, session: DropSession) -> DropConfiguration {
        let operation = Self.resolvedOperation(for: session, target: container(of: node))
        return DropConfiguration(operation: operation)
    }

    static func resolvedOperation(for session: DropSession, target: URL) -> DropOperation {
        guard let localSession = session.localSession else { return .copy }

        let sources = localSession.draggedItemIDs(for: URL.self)
        guard
            !sources.isEmpty,
            sources.allSatisfy({ !FileOperations.looksNested(target, inside: $0) })
        else {
            return .forbidden
        }

        let operation: DropOperation = session.suggestedOperations.contains(.move) ? .move : .copy

        return moveOperation(operation, sources: sources, target: target)
    }

    static func moveOperation(
        _ operation: DropOperation,
        sources: [URL],
        target: URL
    ) -> DropOperation {
        guard operation == .move else { return operation }

        let normalizedTarget = target.standardizedFileURL
        let redundant = sources.allSatisfy {
            $0.deletingLastPathComponent().standardizedFileURL == normalizedTarget
        }

        return redundant ? .forbidden : operation
    }

    func sessionUpdated(_ session: DropSession, for node: FileNode) {
        switch session.phase {
        case .entering, .active:
            if dropTarget != node.url { dropTarget = node.url }
            scheduleExpansion(for: node)

        case .exiting, .ended, .dataTransferCompleted:
            if dropTarget == node.url { dropTarget = nil }
            cancelExpansion(for: node)

        default:
            break
        }
    }

    func scheduleExpansion(for node: FileNode) {
        guard node.isDirectory, !node.isExpanded else { return }
        guard expandTarget != node.url else { return }

        expandTask?.cancel()
        expandTarget = node.url

        expandTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(600))
            guard !Task.isCancelled, expandTarget == node.url else { return }

            withAnimation(.smooth(duration: 0.2)) { node.expand() }
        }
    }

    func cancelExpansion(for node: FileNode) {
        guard expandTarget == node.url else { return }

        expandTask?.cancel()
        expandTask = nil
        expandTarget = nil
    }

    func handleDrop(_ items: [URL], onto node: FileNode, session: DropSession) {
        let sources = items.filter(\.isFileURL)
        guard !sources.isEmpty else { return }

        let target = container(of: node)
        let operation = Self.resolvedOperation(for: session, target: target)
        guard operation == .move || operation == .copy else { return }

        dropTarget = nil

        Task {
            do {
                let results = operation == .move
                    ? try await FileOperations.move(sources, into: target)
                    : try await FileOperations.copy(sources, into: target)

                if let last = results.last { selected = last }
            } catch {
                failure = error.localizedDescription
            }
        }
    }

    func reveal(_ target: URL?, in root: FileNode, proxy: ScrollViewProxy) {
        guard let target, let node = root.reveal(target) else { return }

        withAnimation(.smooth(duration: 0.2)) {
            proxy.scrollTo(node.url, anchor: .center)
        }
    }

    @ViewBuilder
    func rootMenu(_ root: FileNode) -> some View {
        Button("Новый файл…") { ask(.newFile, at: root.url) }
        Button("Новая папка…") { ask(.newFolder, at: root.url) }

        Divider()

        Button("Вставить") { paste(into: root.url) }
            .disabled(FilePasteboard.urls.isEmpty)
    }

    @ViewBuilder
    func menu(_ node: FileNode) -> some View {
        Button("Новый файл…") { ask(.newFile, at: container(of: node)) }
        Button("Новая папка…") { ask(.newFolder, at: container(of: node)) }

        Divider()

        Button("Переименовать…") { ask(.rename, at: node.url) }
        Button("Показать в Finder") { NSWorkspace.shared.activateFileViewerSelecting([node.url]) }
        Button("Скопировать путь") { copyPath(node.url) }

        Divider()

        Button("Копировать") { FilePasteboard.write([node.url]) }

        Button("Вставить") { paste(into: container(of: node)) }
            .disabled(FilePasteboard.urls.isEmpty)

        Divider()

        Button("Удалить", role: .destructive) { perform { try FileOperations.trash(node.url) } }
    }

    func container(of node: FileNode) -> URL {
        node.isDirectory ? node.url : node.url.deletingLastPathComponent()
    }

    func paste(into directory: URL) {
        let urls = FilePasteboard.urls
        guard !urls.isEmpty else { return }

        Task {
            do {
                try await FileOperations.copy(urls, into: directory)
            } catch {
                failure = error.localizedDescription
            }
        }
    }

    func copyPath(_ url: URL) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(url.path(percentEncoded: false), forType: .string)
    }

    func ask(_ kind: FilePrompt.Kind, at target: URL) {
        if case .rename = kind {
            name = target.lastPathComponent
        } else {
            name = ""
        }

        prompt = FilePrompt(kind: kind, target: target)
    }

    func commit() {
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

    @discardableResult
    func perform(_ action: () throws -> Void) -> Bool {
        do {
            try action()
            return true
        } catch {
            failure = error.localizedDescription
            return false
        }
    }
}
