import Foundation

@MainActor
@Observable
final class BranchReviewStore {

    struct Review: Sendable {

        let changes: [GitChange]
        let commits: [GitCommitChanges]
        let loadedAt: Date

        var isStale = false
    }

    private enum Limit {

        // Почему: полсотни коммитов читаются за десятки миллисекунд даже на большой истории
        static let commits = 50

        static let freshness: TimeInterval = 60
        static let cached = 24
    }

    private var entries: [String: Review] = [:]

    @ObservationIgnored
    private var generations: [String: Int] = [:]

    @ObservationIgnored
    private var counter = 0

    @ObservationIgnored
    private var running: [String: Int] = [:]

    private var revisions: [String: Int] = [:]

    @ObservationIgnored
    private var loading: [String: Task<Void, Never>] = [:]

    private static func key(_ root: String, _ branch: String, _ isCurrent: Bool) -> String {
        root + "\n" + branch + "\n" + (isCurrent ? "current" : "other")
    }

    func review(root: String, branch: String, isCurrent: Bool) -> Review? {
        entries[Self.key(root, branch, isCurrent)]
    }

    @discardableResult
    func load(root: String, branch: String, isCurrent: Bool, retries: Int = 1) async -> Bool {
        let key = Self.key(root, branch, isCurrent)

        let started = token(for: key)

        guard needsLoad(key) else { return true }

        // Почему: ждать имеет смысл только загрузку своего поколения, старую — нет
        if let task = loading[key], running[key] == started {
            await task.value
            await repeatIfStale(
                key: key,
                root: root,
                branch: branch,
                isCurrent: isCurrent,
                was: started,
                retries: retries
            )

            return entries[key] != nil
        }

        let task = Task { [weak self] in
            let url = URL(filePath: root)
            // Почему: незакоммиченное есть только у текущей ветки, у остальных читаем историю
            let changes = isCurrent ? await GitClient.workingChanges(at: url) : []
            let commits = await GitClient.history(of: branch, at: url, limit: Limit.commits)

            guard let changes, let commits else { return }

            self?.store(
                Review(changes: changes, commits: commits, loadedAt: Date()),
                at: key,
                generation: started
            )
        }

        loading[key] = task
        running[key] = started
        await task.value

        if running[key] == started {
            loading[key] = nil
            running[key] = nil
            trim()
        }

        // Почему: пока грузились, состояние могли объявить устаревшим — идём ещё раз
        await repeatIfStale(
            key: key,
            root: root,
            branch: branch,
            isCurrent: isCurrent,
            was: started,
            retries: retries
        )

        // Почему: данные есть, пусть и не самые свежие — панель откроется и догонит следующим кругом
        return entries[key] != nil
    }

    // Почему: показанное ревью держится до успешной замены, иначе панель мигает пустотой
    func forget(root: String) {
        let keys = Set(entries.keys).union(loading.keys)

        // Почему: монотонный токен исключает совпадение поколений после вытеснения
        for key in keys where key.hasPrefix(root + "\n") {
            counter += 1
            generations[key] = counter
            entries[key]?.isStale = true
        }
    }

    func revision(root: String, branch: String, isCurrent: Bool) -> Int {
        revisions[Self.key(root, branch, isCurrent)] ?? 0
    }

    // Почему: устаревшая запись — не результат загрузки, ключ ревью по ней менять нельзя
    private func isFresh(_ key: String) -> Bool {
        entries[key] != nil && !needsLoad(key)
    }

    private func token(for key: String) -> Int {
        if let known = generations[key] { return known }

        counter += 1
        generations[key] = counter

        return counter
    }

    private func repeatIfStale(
        key: String,
        root: String,
        branch: String,
        isCurrent: Bool,
        was started: Int,
        retries: Int
    ) async {
        guard retries > 0, generations[key] != started else { return }

        await load(root: root, branch: branch, isCurrent: isCurrent, retries: retries - 1)
    }

    private func needsLoad(_ key: String) -> Bool {
        guard let entry = entries[key], !entry.isStale else { return true }

        return Date().timeIntervalSince(entry.loadedAt) >= Limit.freshness
    }

    private func store(_ review: Review, at key: String, generation started: Int) {
        guard generations[key] == started else { return }

        entries[key] = review
        revisions[key, default: 0] += 1
        trim()
    }

    // Почему: поколение ключа переживает вытеснение, иначе поздняя задача воскресит запись
    private func trim() {
        let free = entries.keys.filter { loading[$0] == nil }

        if entries.count > Limit.cached, !free.isEmpty {
            let stale = free
                .sorted {
                    entries[$0]?.loadedAt ?? .distantPast < entries[$1]?.loadedAt ?? .distantPast
                }
                .prefix(entries.count - Limit.cached)

            for key in stale {
                entries.removeValue(forKey: key)
                revisions.removeValue(forKey: key)
            }
        }

        generations = generations.filter { entries[$0.key] != nil || loading[$0.key] != nil }
    }
}
