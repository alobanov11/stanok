import Foundation

public enum AgentSessionsVisibility {

    public enum Keys {

        public static let includeServiceSessions = "agentSessions.includeServiceSessions"
    }

    public enum Defaults {

        public static let includeServiceSessions = false
    }

    public static var includesServiceSessions: Bool {
        UserDefaults.standard.object(forKey: Keys.includeServiceSessions) as? Bool
            ?? Defaults.includeServiceSessions
    }
}
