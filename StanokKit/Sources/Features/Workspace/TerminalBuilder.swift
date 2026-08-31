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

    public let onFocused: () -> Void
}

public typealias TerminalBuilder<Terminal: View> = (TerminalRequest) -> Terminal
