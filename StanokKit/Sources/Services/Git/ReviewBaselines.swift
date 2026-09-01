import Foundation

actor ReviewBaselines {

    private struct Entry {

        var base: String
        var cleanSince: Date?
    }

    static let shared = ReviewBaselines()

    private static let expiry: TimeInterval = 600

    private var entries: [String: Entry] = [:]

    // Почему: правку читают и после коммита, поэтому точка отсчёта держится до затишья
    func base(for root: String, head: String, isClean: Bool, now: Date = Date()) -> String {
        var entry = entries[root] ?? Entry(base: head, cleanSince: isClean ? now : nil)

        if !isClean {
            entry.cleanSince = nil
        } else if entry.base == head {
            entry.cleanSince = now
        } else if let since = entry.cleanSince {
            if now.timeIntervalSince(since) > Self.expiry {
                entry = Entry(base: head, cleanSince: now)
            }
        } else {
            entry.cleanSince = now
        }

        entries[root] = entry

        return entry.base
    }
}
