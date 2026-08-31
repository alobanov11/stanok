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

    static func isPreviewSplit(hasPreview: Bool, width: CGFloat) -> Bool {
        hasPreview && width >= WorkspaceLayout.minimumSplitWidth
    }

    static func previewTransition(split: Bool) -> AnyTransition {
        split ? .move(edge: .trailing).combined(with: .opacity) : .opacity
    }

    static func headerLeading(sidebarExpanded: Bool) -> CGFloat {
        guard !sidebarExpanded else { return expandedHeaderLeading }

        return WorkspaceLayout.toggleWidth + WorkspaceLayout.toggleGap * 2
    }
}
