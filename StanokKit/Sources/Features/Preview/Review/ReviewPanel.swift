import SwiftUI

struct ReviewPanel: View {

    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay(alignment: .top) { bar }
    }

    private var bar: some View {
        HStack(spacing: 8) {
            if let previousName {
                PreviewBackIndicator(name: previousName, action: onBack)
            }

            Text(set.name)
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
        if set.files.isEmpty {
            Text("Изменений нет")
                .font(Typography.caption)
                .foregroundStyle(.tertiary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(set.files.enumerated()), id: \.element.id) { index, file in
                        if
                            let group = file.group, group != set.files[max(index - 1, 0)].group
                            || index == 0 {
                            SectionHeader(title: group)
                        }

                        ReviewFileCard(file: file, isExpanded: index == 0)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.top, WorkspaceLayout.headerHeight)
                .padding(.bottom, 12)
            }
        }
    }

    let set: ReviewSet
    let leadingInset: CGFloat
    let previousName: String?
    let onBack: () -> Void
}
