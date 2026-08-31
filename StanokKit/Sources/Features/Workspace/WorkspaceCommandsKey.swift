import SwiftUI

private struct WorkspaceCommandsKey: FocusedValueKey {

    typealias Value = WorkspaceCommandActions
}

public extension FocusedValues {

    var workspaceCommands: WorkspaceCommandActions? {
        get { self[WorkspaceCommandsKey.self] }
        set { self[WorkspaceCommandsKey.self] = newValue }
    }
}
