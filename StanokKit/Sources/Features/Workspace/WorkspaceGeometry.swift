import SwiftUI

enum WorkspaceGeometry {

    static let expandedHeaderLeading: CGFloat = 14

    static var insideOffset: CGFloat {
        WorkspaceLayout.inset + WorkspaceLayout.toggleGap
    }

    static var outsideLeading: CGFloat {
        WorkspaceLayout.sidebarWidth
            - controlWidth(sidebarExpanded: true)
            - WorkspaceLayout.toggleGap
    }

    static var toggleTop: CGFloat {
        WorkspaceLayout.inset + (WorkspaceLayout.headerHeight - WorkspaceLayout.toggleHeight) / 2
    }

    static func controlWidth(sidebarExpanded: Bool) -> CGFloat {
        sidebarExpanded ? WorkspaceLayout.toggleWidth * 2 : WorkspaceLayout.toggleWidth
    }

    static func toggleLeading(sidebarExpanded: Bool) -> CGFloat {
        sidebarExpanded ? outsideLeading : insideOffset
    }

    // Почему: если после превью терминалу не остаётся ширины, превью ложится поверх него
    static func previewMode(hasPreview: Bool, width: CGFloat) -> PreviewMode {
        guard hasPreview else { return .none }

        let needed = WorkspaceLayout.minimumTerminalWidth
            + WorkspaceLayout.minimumPreviewWidth
            + WorkspaceLayout.inset

        return width >= needed ? .split : .fullScreen
    }

    static func previewTransition(for mode: PreviewMode) -> AnyTransition {
        mode == .split ? .move(edge: .trailing).combined(with: .opacity) : .opacity
    }

    static func headerLeading(sidebarExpanded: Bool) -> CGFloat {
        guard !sidebarExpanded else { return expandedHeaderLeading }

        return WorkspaceLayout.toggleWidth + WorkspaceLayout.toggleGap * 2
    }
}
