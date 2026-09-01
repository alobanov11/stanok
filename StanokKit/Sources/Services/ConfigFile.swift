import Foundation

public enum ConfigFile {

    public static let changed = Notification.Name("stanok.config.changed")

    public static func value(for key: String) -> String? {
        guard let text = try? String(contentsOf: AppPaths.ghosttyConfig, encoding: .utf8)
        else { return nil }

        for line in text.split(whereSeparator: \.isNewline) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard
                !trimmed.hasPrefix("#"),
                let separator = trimmed.firstIndex(of: "=")
            else { continue }
            guard trimmed[..<separator].trimmingCharacters(in: .whitespaces) == key
            else { continue }

            return trimmed[trimmed.index(after: separator)...].trimmingCharacters(in: .whitespaces)
        }
        return nil
    }

    public static func remove(_ key: String) {
        let url = AppPaths.ghosttyConfig
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { return }

        let kept = text.components(separatedBy: .newlines).filter { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.hasPrefix("#"), let separator = trimmed.firstIndex(of: "=")
            else { return true }

            return trimmed[..<separator].trimmingCharacters(in: .whitespaces) != key
        }

        do {
            try kept.joined(separator: "\n").write(to: url, atomically: true, encoding: .utf8)
            NotificationCenter.default.post(name: changed, object: nil)
        } catch {
            Log.terminal.error("cannot write config: \(error.localizedDescription)")
        }
    }

    public static func set(_ key: String, to value: String) {
        let url = AppPaths.ghosttyConfig
        var lines = (try? String(contentsOf: url, encoding: .utf8))?
            .components(separatedBy: .newlines) ?? []

        let replacement = "\(key) = \(value)"
        var replaced = false
        for index in lines.indices {
            let trimmed = lines[index].trimmingCharacters(in: .whitespaces)
            guard
                !trimmed.hasPrefix("#"),
                let separator = trimmed.firstIndex(of: "=")
            else { continue }
            guard trimmed[..<separator].trimmingCharacters(in: .whitespaces) == key
            else { continue }

            lines[index] = replacement
            replaced = true
            break
        }
        if !replaced { lines.append(replacement) }

        do {
            try lines.joined(separator: "\n").write(to: url, atomically: true, encoding: .utf8)
            NotificationCenter.default.post(name: changed, object: nil)
        } catch {
            Log.terminal.error("cannot write config: \(error.localizedDescription)")
        }
    }
}
