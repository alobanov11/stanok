import SwiftUI

struct ReviewPanel: View {

    private var title: String {
        let count = files.count
        let word = PluralForm.of(count, "файл", "файла", "файлов")

        return "\(kind.title) — \(count) \(word)"
    }

    @State
    private var expanded: Set<URL> = []

    @State
    private var collapsed: Set<URL> = []

    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay(alignment: .top) { bar }
            .onChange(of: kind) { _, _ in
                expanded = []
                collapsed = []
            }
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
        .background(alignment: .top) { PanelHeaderBackground() }
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

                        ReviewFileCard(file: file, isExpanded: expansion(for: file, at: index))
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

    private func expansion(for file: ReviewFile, at index: Int) -> Binding<Bool> {
        Binding(
            get: {
                if collapsed.contains(file.url) { return false }

                return expanded.contains(file.url) || (index == 0 && file.status != .deleted)
            },
            set: { isOpen in
                if isOpen {
                    expanded.insert(file.url)
                    collapsed.remove(file.url)
                } else {
                    expanded.remove(file.url)
                    collapsed.insert(file.url)
                }
            }
        )
    }

    private func groupName(at index: Int) -> String? {
        guard let name = files[index].groupName else { return nil }
        guard index > 0 else { return name }

        return files[index - 1].root == files[index].root ? nil : name
    }
}
