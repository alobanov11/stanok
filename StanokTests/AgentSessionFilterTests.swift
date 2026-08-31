import Foundation
import Testing

import StanokKit

struct AgentSessionFilterTests {

    private static func session(title: String, folder: URL?) -> AgentSession {
        AgentSession(
            id: AgentSessionKey(providerID: "fake", sessionID: UUID().uuidString),
            title: title,
            lastActivityAt: .now,
            resumeAction: AgentResumeAction(executable: "claude", arguments: []),
            folder: folder
        )
    }

    @Test
    func emptyQueryMatchesEverything() {
        let session = Self.session(title: "Fix the login bug", folder: nil)

        #expect(AgentSessionFilter.matches(session, query: ""))
        #expect(AgentSessionFilter.matches(session, query: "   "))
    }

    @Test
    func matchesTitleCaseInsensitively() {
        let session = Self.session(title: "Fix the LOGIN bug", folder: nil)

        #expect(AgentSessionFilter.matches(session, query: "login"))
        #expect(!AgentSessionFilter.matches(session, query: "logout"))
    }

    @Test
    func matchesFolderCaseInsensitively() {
        let session = Self.session(
            title: "Unrelated title",
            folder: URL(fileURLWithPath: "/Users/test/Sorok-Web-App")
        )

        #expect(AgentSessionFilter.matches(session, query: "sorok-web-app"))
        #expect(!AgentSessionFilter.matches(session, query: "stanok"))
    }

    @Test
    func applyFiltersTheList() {
        let dashboardFolder = URL(fileURLWithPath: "/Users/test/dashboard")
        let sessions = [
            Self.session(title: "Fix the login bug", folder: nil),
            Self.session(title: "Add a dashboard chart", folder: dashboardFolder)
        ]

        let filtered = AgentSessionFilter.apply("dashboard", to: sessions)

        #expect(filtered.map(\.title) == ["Add a dashboard chart"])
    }
}
