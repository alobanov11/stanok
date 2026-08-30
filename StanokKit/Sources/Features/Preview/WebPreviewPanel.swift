import SwiftUI

struct WebPreviewPanel: View {

    var body: some View {
        VStack(spacing: 0) {
            bar
            Divider().opacity(0.4)
            WebContentView(url: preview.url)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var bar: some View {
        HStack(spacing: 8) {
            if let previousName {
                PreviewBackIndicator(name: previousName)
            }

            Text(preview.name)
                .font(Typography.heading)
                .tracking(Typography.headingTracking)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer(minLength: 8)
        }
        .padding(.leading, leadingInset)
        .padding(.trailing, WorkspaceLayout.toggleHeight + WorkspaceLayout.toggleGap * 2)
        .frame(height: WorkspaceLayout.headerHeight)
    }

    let preview: WebPreview

    let leadingInset: CGFloat

    let previousName: String?

}
