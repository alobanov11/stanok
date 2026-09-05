import SwiftUI

struct PreviewPanel: View {

    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .mask(alignment: .top) { PanelHeaderFade() }
            .overlay(alignment: .top) { bar }
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
        .frame(height: WorkspaceLayout.headerHeight, alignment: .center)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var content: some View {
        switch preview.content {
        case .markdown, .code:
            PreviewContentView(preview: preview, topInset: WorkspaceLayout.headerHeight)

        case let .image(image):
            ScrollView {
                ImagePreviewView(image: image, topInset: WorkspaceLayout.headerHeight)
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
