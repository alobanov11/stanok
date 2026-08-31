import AppKit
import GhosttyKit

enum GhosttyCursorShape {

    static func cursor(for shape: ghostty_action_mouse_shape_e) -> NSCursor? {
        switch shape {
        case GHOSTTY_MOUSE_SHAPE_DEFAULT: .arrow
        case GHOSTTY_MOUSE_SHAPE_TEXT: .iBeam
        case GHOSTTY_MOUSE_SHAPE_GRAB: .openHand
        case GHOSTTY_MOUSE_SHAPE_GRABBING: .closedHand
        case GHOSTTY_MOUSE_SHAPE_POINTER: .pointingHand
        case GHOSTTY_MOUSE_SHAPE_VERTICAL_TEXT: .iBeamCursorForVerticalLayout
        case GHOSTTY_MOUSE_SHAPE_CONTEXT_MENU: .contextualMenu
        case GHOSTTY_MOUSE_SHAPE_CROSSHAIR: .crosshair
        case GHOSTTY_MOUSE_SHAPE_NOT_ALLOWED: .operationNotAllowed
        case GHOSTTY_MOUSE_SHAPE_W_RESIZE: .columnResize(directions: .left)
        case GHOSTTY_MOUSE_SHAPE_E_RESIZE: .columnResize(directions: .right)
        case GHOSTTY_MOUSE_SHAPE_N_RESIZE: .rowResize(directions: .up)
        case GHOSTTY_MOUSE_SHAPE_S_RESIZE: .rowResize(directions: .down)
        case GHOSTTY_MOUSE_SHAPE_NS_RESIZE: .rowResize
        case GHOSTTY_MOUSE_SHAPE_EW_RESIZE: .columnResize
        default: nil
        }
    }

}
