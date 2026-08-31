import SwiftUI

struct WorkspacePanelStyle: ViewModifier {

    let width: CGFloat

    func body(content: Content) -> some View {
        content
            .frame(width: width)
            .background {
                WorkspaceLayout.cardStyle.background(radius: WorkspaceLayout.cardRadius)
            }
            .clipShape(.rect(cornerRadius: WorkspaceLayout.cardRadius, style: .continuous))
            .padding(.trailing, WorkspaceLayout.inset)
            .padding(.vertical, WorkspaceLayout.inset)
    }
}
