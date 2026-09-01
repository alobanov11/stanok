import SwiftUI

public struct AgentSessionsSettings: View {

    @AppStorage(AgentSessionsVisibility.Keys.includeServiceSessions)
    private var includeServiceSessions = AgentSessionsVisibility.Defaults.includeServiceSessions

    public var body: some View {
        Form {
            Section("Чаты") {
                Toggle("Показывать служебные сессии", isOn: $includeServiceSessions)
                    .onChange(of: includeServiceSessions) { _, _ in
                        NotificationCenter.default.post(
                            name: AgentSessionsVisibility.changed,
                            object: nil
                        )
                    }
            }
        }
        .formStyle(.grouped)
        .scrollDisabled(true)
    }

    public init() {}
}
