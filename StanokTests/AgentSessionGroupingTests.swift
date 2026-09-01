import Foundation
import Testing

@testable import StanokKit

struct AgentSessionGroupingTests {

    private static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Moscow") ?? .gmt
        calendar.locale = Locale(identifier: "ru_RU")
        return calendar
    }

    private static func date(_ raw: String) -> Date {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.date(from: raw) ?? .distantPast
    }

    private static func session(_ at: String) -> AgentSession {
        AgentSession(
            id: AgentSessionKey(providerID: "claude", sessionID: at),
            title: at,
            lastActivityAt: date(at),
            resumeAction: AgentResumeAction(executable: "claude", arguments: [])
        )
    }

    @Test
    func daysGoFromNewestToOldestAndKeepTheirOwnOrder() {
        let days = AgentSessionGrouping.byDay(
            [
                Self.session("2026-08-30 09:00"),
                Self.session("2026-09-01 10:00"),
                Self.session("2026-09-01 18:00")
            ],
            now: Self.date("2026-09-01 20:00"),
            calendar: Self.calendar
        )

        #expect(days.map(\.sessions.count) == [2, 1])
        #expect(days.first?.sessions.first?.title == "2026-09-01 18:00")
    }

    @Test
    func theNearestDaysAreNamedInWords() {
        let now = Self.date("2026-09-01 20:00")

        #expect(AgentSessionGrouping.title(
            for: Self.date("2026-09-01 00:00"), now: now, calendar: Self.calendar
        ) == "Сегодня")

        #expect(AgentSessionGrouping.title(
            for: Self.date("2026-08-31 00:00"), now: now, calendar: Self.calendar
        ) == "Вчера")
    }

    @Test
    func anOlderDayFallsBackToItsDate() {
        let now = Self.date("2026-09-01 20:00")
        let title = AgentSessionGrouping.title(
            for: Self.date("2026-08-01 00:00"), now: now, calendar: Self.calendar
        )

        #expect(title == "1 августа")
    }

    @Test
    func aDayFromAnotherYearKeepsTheYear() {
        let now = Self.date("2026-09-01 20:00")
        let title = AgentSessionGrouping.title(
            for: Self.date("2025-12-31 00:00"), now: now, calendar: Self.calendar
        )

        #expect(title == "31 декабря 2025")
    }
}
