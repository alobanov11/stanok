import SwiftUI

private struct AgentChangesKey: EnvironmentKey {

    static let defaultValue: AgentChangesModel? = nil
}

public extension EnvironmentValues {

    var agentChanges: AgentChangesModel? {
        get { self[AgentChangesKey.self] }
        set { self[AgentChangesKey.self] = newValue }
    }
}
