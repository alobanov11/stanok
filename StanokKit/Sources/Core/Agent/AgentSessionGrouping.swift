import Foundation

public enum AgentSessionGrouping {

    public static func byDay(
        _ sessions: [AgentSession],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> [AgentSessionDay] {
        let grouped = Dictionary(grouping: sessions) {
            calendar.startOfDay(for: $0.lastActivityAt)
        }

        return grouped.keys.sorted(by: >).map { start in
            AgentSessionDay(
                start: start,
                title: title(for: start, now: now, calendar: calendar),
                sessions: (grouped[start] ?? []).sorted { $0.lastActivityAt > $1.lastActivityAt }
            )
        }
    }

    public static func title(for day: Date, now: Date, calendar: Calendar) -> String {
        if calendar.isDateInToday(day) { return "Сегодня" }
        if calendar.isDateInYesterday(day) { return "Вчера" }

        let days = calendar.dateComponents([.day], from: day, to: calendar.startOfDay(for: now)).day
        if let days, days >= 0, days < 7 {
            return weekday.string(from: day).capitalized
        }

        let sameYear = calendar.component(.year, from: day) == calendar.component(.year, from: now)

        return (sameYear ? short : full).string(from: day)
    }
}

private extension AgentSessionGrouping {

    nonisolated(unsafe) static let weekday: DateFormatter = formatter("EEEE")

    nonisolated(unsafe) static let short: DateFormatter = formatter("d MMMM")

    nonisolated(unsafe) static let full: DateFormatter = formatter("d MMMM yyyy")

    static func formatter(_ template: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = template
        return formatter
    }
}
