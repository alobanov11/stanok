public enum FilePanelModeTransition: Equatable {

    case closes

    case opens(FilePanelMode)

    case switches(FilePanelMode)

    public var nextMode: FilePanelMode? {
        switch self {
        case .closes:
            nil
        case let .opens(mode), let .switches(mode):
            mode
        }
    }

    public var animates: Bool {
        switch self {
        case .closes, .opens:
            true
        case .switches:
            false
        }
    }

    public static func resolve(
        current: FilePanelMode?,
        requested: FilePanelMode
    ) -> FilePanelModeTransition {
        if current == requested {
            .closes
        } else if current == nil {
            .opens(requested)
        } else {
            .switches(requested)
        }
    }
}
