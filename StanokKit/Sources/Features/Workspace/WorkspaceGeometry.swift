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

    // Почему: на вертикальном мониторе колонки не помещаются, поэтому область делится по высоте
    static func isVertical(_ size: CGSize) -> Bool {
        size.height > size.width
    }

    // Почему: если после превью терминалу не остаётся места, превью ложится поверх него
    static func previewMode(hasPreview: Bool, size: CGSize) -> PreviewMode {
        guard hasPreview else { return .none }

        let vertical = isVertical(size)
        let needed = vertical
            ? WorkspaceLayout.minimumTerminalHeight + WorkspaceLayout.minimumPreviewHeight
            : WorkspaceLayout.minimumTerminalWidth + WorkspaceLayout.minimumPreviewWidth
        let room = vertical ? size.height : size.width

        return room >= needed + WorkspaceLayout.inset ? .split : .fullScreen
    }

    static func previewTransition(for mode: PreviewMode, isVertical: Bool) -> AnyTransition {
        guard mode == .split else { return .opacity }

        return .move(edge: isVertical ? .bottom : .trailing).combined(with: .opacity)
    }

    static func headerLeading(sidebarExpanded: Bool) -> CGFloat {
        guard !sidebarExpanded else { return expandedHeaderLeading }

        return WorkspaceLayout.toggleWidth + WorkspaceLayout.toggleGap * 2
    }
}
