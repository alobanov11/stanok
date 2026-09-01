import Foundation

actor ReviewBaselines {

    private struct Entry {

        var base: String
        var cleanSince: Date?
    }

    private enum Limit {

        static let expiry: TimeInterval = 600
        static let capacity = 32
    }

    static let shared = ReviewBaselines()

    private var entries: [String: Entry] = [:]

    // Почему: правку читают и после коммита, поэтому точка отсчёта держится до затишья
    func base(for root: String, head: String, isClean: Bool, now: Date = Date()) -> String {
        var entry = entries[root] ?? Entry(base: head, cleanSince: isClean ? now : nil)

        if !isClean {
            entry.cleanSince = nil
        } else if entry.base == head {
            entry.cleanSince = now
        } else if let since = entry.cleanSince {
            if now.timeIntervalSince(since) > Limit.expiry {
                entry = Entry(base: head, cleanSince: now)
            }
        } else {
            entry.cleanSince = now
        }

        entries[root] = entry
        // Почему: репозитории приходят и уходят, точки отсчёта не должны копиться навсегда
        if entries.count > Limit.capacity {
            let stale = entries.sorted { ($0.value.cleanSince ?? .distantPast) < ($1.value.cleanSince ?? .distantPast) }
                .prefix(entries.count - Limit.capacity)
                .map(\.key)

            for key in stale {
                entries.removeValue(forKey: key)
            }
        }

        return entry.base
    }
}
