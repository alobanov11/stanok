import SwiftUI

struct WorkspaceCard: ViewModifier {

    func body(content: Content) -> some View {
        content
            .background {
                WorkspaceLayout.cardStyle.background(radius: WorkspaceLayout.cardRadius)
            }
            .clipShape(.rect(cornerRadius: WorkspaceLayout.cardRadius, style: .continuous))
    }
}
