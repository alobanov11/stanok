import Foundation

actor ReviewBaselines {

    private struct Entry {

        var base: String
        var branch: String?
        var cleanSince: Date?
    }

    private enum Limit {

        static let expiry: TimeInterval = 600
        static let capacity = 32
    }

    static let shared = ReviewBaselines()

    private var entries: [String: Entry] = [:]

    // Почему: правку читают и после коммита, поэтому точка отсчёта держится до затишья
    func base(
        for root: String,
        head: String,
        parent: String?,
        branch: String?,
        isClean: Bool,
        now: Date = Date()
    ) -> String {
        // Почему: репозиторий может быть чистым с самого начала, и тогда читают последний коммит
        let start = isClean ? parent ?? head : head
        var entry = kept(root, branch: branch, start: start, isClean: isClean, now: now)

        if !isClean {
            entry.cleanSince = nil
        } else if entry.base == head {
            entry.cleanSince = now
        } else if let since = entry.cleanSince {
            if now.timeIntervalSince(since) > Limit.expiry {
                entry = Entry(base: parent ?? head, branch: branch, cleanSince: now)
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

    // Почему: после checkout прежняя точка отсчёта указывает на чужую линию истории
    private func kept(
        _ root: String,
        branch: String?,
        start: String,
        isClean: Bool,
        now: Date
    ) -> Entry {
        let fresh = Entry(base: start, branch: branch, cleanSince: isClean ? now : nil)
        guard let known = entries[root], known.branch == branch else { return fresh }

        return known
    }
}
