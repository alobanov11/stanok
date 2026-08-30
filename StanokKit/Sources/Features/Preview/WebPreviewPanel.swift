import SwiftUI

struct WebPreviewPanel: View {

    @State
    private var canGoBack = false

    @State
    private var backRequestID = 0

    var body: some View {
        VStack(spacing: 0) {
            bar
            Divider().opacity(0.4)
            WebContentView(url: preview.url, canGoBack: $canGoBack, backRequestID: backRequestID)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var bar: some View {
        HStack(spacing: 8) {
            if let previousName {
                PreviewBackIndicator(name: previousName, action: goBack)
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

    let onBack: () -> Void

    private func goBack() {
        if canGoBack {
            backRequestID += 1
        } else {
            onBack()
        }
    }

}
