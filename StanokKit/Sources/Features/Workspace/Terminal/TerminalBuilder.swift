import SwiftUI

public struct TerminalRequest {

    public let session: TerminalSession
    public let isVisible: Bool
    public let isFocused: Bool
    public let insertRequest: TerminalInsertRequest?
    public let onCommandFinished: (CommandRun) -> Void
    public let onOpenURL: (String) -> Void
    public let onTitleChanged: (String) -> Void
    public let onCloseRequested: (Bool) -> Void
    public let onPwdChanged: (String) -> Void
    public let onInput: () -> Void
    public let onInsertHandled: (UUID) -> Void
    public let closeRequest: UUID?
    public let onCloseHandled: (UUID) -> Void
    public let onFocused: () -> Void
    public let onSnapshot: (String) -> Void
    public let wantsSnapshots: Bool
}

public typealias TerminalBuilder<Terminal: View> = (TerminalRequest) -> Terminal
