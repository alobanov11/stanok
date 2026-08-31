import SwiftUI

private struct AgentSessionRegistryKey: EnvironmentKey {

    static let defaultValue = AgentSessionRegistry()
}

public extension EnvironmentValues {

    var agentSessionRegistry: AgentSessionRegistry {
        get { self[AgentSessionRegistryKey.self] }
        set { self[AgentSessionRegistryKey.self] = newValue }
    }
}
