import SwiftUI

struct PreviewLayer: View {

    var body: some View {
        panel
            .background {
                WorkspaceLayout.cardStyle.background(radius: WorkspaceLayout.cardRadius)
            }
            .overlay(alignment: .topTrailing) { closeButton }
            .zIndex(1)
            .transition(.opacity)
    }

    @ViewBuilder
    private var panel: some View {
        switch entry {
        case let .file(preview):
            PreviewPanel(
                preview: preview,
                leadingInset: leadingInset,
                previousName: previousName,
                onBack: onBack
            )

        case let .web(preview):
            WebPreviewPanel(
                preview: preview,
                leadingInset: leadingInset,
                previousName: previousName,
                onBack: onBack
            )
        }
    }

    private var closeButton: some View {
        CloseButton(action: onClose)
            .padding(.top, (WorkspaceLayout.headerHeight - WorkspaceLayout.toggleHeight) / 2)
            .padding(.trailing, WorkspaceLayout.toggleGap)
    }

    let entry: PreviewEntry

    let leadingInset: CGFloat

    let previousName: String?

    let onBack: () -> Void

    let onClose: () -> Void

}
