import AppKit
import GhosttyKit

enum GhosttyCursorShape {

    static func cursor(for shape: ghostty_action_mouse_shape_e) -> NSCursor {
        switch shape {
        case GHOSTTY_MOUSE_SHAPE_TEXT: .iBeam
        case GHOSTTY_MOUSE_SHAPE_GRAB: .openHand
        case GHOSTTY_MOUSE_SHAPE_GRABBING: .closedHand
        case GHOSTTY_MOUSE_SHAPE_POINTER, GHOSTTY_MOUSE_SHAPE_ALIAS: .pointingHand
        case GHOSTTY_MOUSE_SHAPE_VERTICAL_TEXT: .iBeamCursorForVerticalLayout
        case GHOSTTY_MOUSE_SHAPE_CONTEXT_MENU: .contextualMenu
        case GHOSTTY_MOUSE_SHAPE_CROSSHAIR, GHOSTTY_MOUSE_SHAPE_CELL: .crosshair
        case GHOSTTY_MOUSE_SHAPE_NOT_ALLOWED, GHOSTTY_MOUSE_SHAPE_NO_DROP: .operationNotAllowed
        case GHOSTTY_MOUSE_SHAPE_COPY: .dragCopy
        case GHOSTTY_MOUSE_SHAPE_MOVE, GHOSTTY_MOUSE_SHAPE_ALL_SCROLL: .openHand
        case GHOSTTY_MOUSE_SHAPE_ZOOM_IN: .zoomIn
        case GHOSTTY_MOUSE_SHAPE_ZOOM_OUT: .zoomOut
        case GHOSTTY_MOUSE_SHAPE_W_RESIZE: .columnResize(directions: .left)
        case GHOSTTY_MOUSE_SHAPE_E_RESIZE: .columnResize(directions: .right)
        case GHOSTTY_MOUSE_SHAPE_N_RESIZE: .rowResize(directions: .up)
        case GHOSTTY_MOUSE_SHAPE_S_RESIZE: .rowResize(directions: .down)
        case GHOSTTY_MOUSE_SHAPE_NS_RESIZE, GHOSTTY_MOUSE_SHAPE_ROW_RESIZE: .rowResize
        case GHOSTTY_MOUSE_SHAPE_EW_RESIZE, GHOSTTY_MOUSE_SHAPE_COL_RESIZE: .columnResize
        case GHOSTTY_MOUSE_SHAPE_NE_RESIZE, GHOSTTY_MOUSE_SHAPE_SW_RESIZE,
             GHOSTTY_MOUSE_SHAPE_NESW_RESIZE:
            .frameResize(position: .topRight, directions: .all)
        case GHOSTTY_MOUSE_SHAPE_NW_RESIZE, GHOSTTY_MOUSE_SHAPE_SE_RESIZE,
             GHOSTTY_MOUSE_SHAPE_NWSE_RESIZE:
            .frameResize(position: .topLeft, directions: .all)
        default: .arrow
        }
    }
}
