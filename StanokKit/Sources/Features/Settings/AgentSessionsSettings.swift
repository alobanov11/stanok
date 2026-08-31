import SwiftUI

public struct AgentSessionsSettings: View {

    @AppStorage(AgentSessionsVisibility.Keys.includeServiceSessions)
    private var includeServiceSessions = AgentSessionsVisibility.Defaults.includeServiceSessions

    public var body: some View {
        Form {
            Section("Чаты") {
                Toggle("Показывать служебные сессии", isOn: $includeServiceSessions)
            }
        }
        .formStyle(.grouped)
        .scrollDisabled(true)
    }

    public init() {}
}
