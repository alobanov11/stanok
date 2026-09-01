import SwiftUI

struct PreviewLayer: View {

    var body: some View {
        panel
            .modifier(WorkspaceCard())
            .overlay(alignment: .topTrailing) { closeButton }
            .zIndex(1)
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

        case let .review(set):
            ReviewPanel(
                set: set,
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
