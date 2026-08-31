import CoreFoundation

enum WorkspaceGeometry {

    static let expandedHeaderLeading: CGFloat = 14

    static var insideOffset: CGFloat {
        WorkspaceLayout.inset + WorkspaceLayout.toggleGap
    }

    static var outsideLeading: CGFloat {
        WorkspaceLayout.sidebarWidth - WorkspaceLayout.toggleWidth - WorkspaceLayout.toggleGap
    }

    static var toggleTop: CGFloat {
        WorkspaceLayout.inset + (WorkspaceLayout.headerHeight - WorkspaceLayout.toggleHeight) / 2
    }

    static func toggleLeading(sidebarExpanded: Bool) -> CGFloat {
        sidebarExpanded ? outsideLeading : insideOffset
    }

    static func headerLeading(sidebarExpanded: Bool) -> CGFloat {
        guard !sidebarExpanded else { return expandedHeaderLeading }

        return WorkspaceLayout.toggleWidth + WorkspaceLayout.toggleGap * 2
    }
}
