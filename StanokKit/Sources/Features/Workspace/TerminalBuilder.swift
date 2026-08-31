import SwiftUI

public typealias TerminalBuilder<Terminal: View> = (
    TerminalSession,
    Bool,
    TerminalInsertRequest?,
    @escaping (CommandRun) -> Void,
    @escaping (String) -> Void,
    @escaping (String) -> Void,
    @escaping (Bool) -> Void,
    @escaping (String) -> Void
) -> Terminal
