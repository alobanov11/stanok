import SwiftUI

struct PreviewPanel: View {

    var body: some View {
        VStack(spacing: 0) {
            bar
            Divider().opacity(0.4)
            content
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var bar: some View {
        HStack(spacing: 8) {
            if let previousName {
                PreviewBackIndicator(name: previousName, action: onBack)
            }

            Text(preview.name)
                .font(Typography.heading)
                .tracking(Typography.headingTracking)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)

            if preview.isTruncated {
                Text("показаны первые 5000 строк")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }

            Spacer(minLength: 8)
        }
        .padding(.leading, leadingInset)
        .padding(.trailing, WorkspaceLayout.toggleHeight + WorkspaceLayout.toggleGap * 2)
        .frame(height: WorkspaceLayout.headerHeight)
    }

    @ViewBuilder
    private var content: some View {
        switch preview.content {
        case let .markdown(blocks):
            ScrollView {
                MarkdownView(blocks: blocks)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 18)
            }

        case let .code(lines):
            ScrollView(.vertical) {
                CodeBlockView(lines: lines, showsNumbers: true, changes: preview.changes)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

        default:
            FileInfoView(preview: preview)
        }
    }

    let preview: FilePreview
    let leadingInset: CGFloat
    let previousName: String?
    let onBack: () -> Void
}
