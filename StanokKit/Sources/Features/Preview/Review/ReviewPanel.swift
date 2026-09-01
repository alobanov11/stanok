import SwiftUI

struct ReviewPanel: View {

    private static let opened = 4

    private var title: String {
        let count = files.count
        let word = PluralForm.of(count, "файл", "файла", "файлов")

        return "\(kind.title) — \(count) \(word)"
    }

    private var stamp: String {
        kind.key + "\n" + files.map(\.id).joined(separator: "\n")
    }

    @State
    private var expanded: Set<String> = []

    @State
    private var collapsed: Set<String> = []

    @State
    private var initial: String?

    @State
    private var cache = PreviewCache()

    @State
    private var order: [String] = []

    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .mask(alignment: .top) { PanelHeaderFade() }
            .overlay(alignment: .top) { bar }
            .onChange(of: kind) { _, _ in
                expanded = []
                collapsed = []
                initial = nil
            }
            .task(id: stamp) { adopt() }
    }

    private var bar: some View {
        HStack(spacing: 8) {
            if let previousName {
                PreviewBackIndicator(name: previousName, action: onBack)
            }

            Text(title)
                .font(Typography.heading)
                .tracking(Typography.headingTracking)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Spacer(minLength: 8)
        }
        .padding(.leading, leadingInset)
        .padding(.trailing, WorkspaceLayout.toggleHeight + WorkspaceLayout.toggleGap * 2)
        .frame(height: WorkspaceLayout.headerHeight, alignment: .center)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var content: some View {
        if files.isEmpty {
            Text("Изменений нет")
                .font(Typography.caption)
                .foregroundStyle(.tertiary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(files.enumerated()), id: \.element.id) { index, file in
                        if let name = groupName(at: index) {
                            SectionHeader(title: name)
                        }

                        ReviewFileCard(
                            file: file,
                            revision: revision,
                            cache: cache,
                            onOpen: onOpen,
                            isExpanded: expansion(for: file)
                        )
                    }
                }
                .padding(.horizontal, 12)
                .padding(.top, WorkspaceLayout.headerHeight)
                .padding(.bottom, 12)
            }
        }
    }

    let kind: ReviewKind
    let files: [ReviewFile]
    let leadingInset: CGFloat
    let previousName: String?
    let onBack: () -> Void
    let revision: String
    let onOpen: (URL) -> Void

    private func expansion(for file: ReviewFile) -> Binding<Bool> {
        Binding(
            get: {
                if collapsed.contains(file.id) { return false }

                return expanded.contains(file.id) || file.id == initial
            },
            set: { isOpen in
                if isOpen {
                    open(file.id)
                } else {
                    expanded.remove(file.id)
                    collapsed.insert(file.id)
                }
            }
        )
    }

    // Почему: каждая раскрытая карточка держит документ файла, поэтому их число ограничено
    private func open(_ id: String) {
        let present = Set(files.map(\.id))
        order = order.filter { present.contains($0) }
        expanded.insert(id)
        collapsed.remove(id)
        order.removeAll { $0 == id }
        order.append(id)

        while order.count > Self.opened, let oldest = order.first {
            order.removeFirst()
            expanded.remove(oldest)
            collapsed.insert(oldest)
        }
    }

    private func adopt() {
        let present = Set(files.map(\.id))
        expanded.formIntersection(present)
        collapsed.formIntersection(present)

        if let initial, present.contains(initial) { return }

        // Почему: пока раскрытая человеком карточка в списке, не отбираем её ради первой
        guard expanded.isEmpty else {
            initial = nil
            return
        }

        initial = files.first { $0.status != .deleted }?.id

        if let initial { open(initial) }
    }

    private func groupName(at index: Int) -> String? {
        guard let name = files[index].groupName else { return nil }
        guard index > 0 else { return name }

        return files[index - 1].groupName == name ? nil : name
    }
}
