import Darwin
import Foundation

@MainActor
public final class ShellProcessLabelStore {

    public nonisolated static let environmentVariable = "STANOK_TAB_ID"

    private let directory: URL

    public init(directory: URL = AppPaths.shellProcessLabels) {
        self.directory = directory
    }

    public func pid(forLabel label: String) -> Int32? {
        let file = directory.appending(path: label, directoryHint: .notDirectory)
        guard
            let data = try? Data(contentsOf: file),
            let contents = String(data: data, encoding: .utf8),
            let value = Int32(contents.trimmingCharacters(in: .whitespacesAndNewlines)),
            value > 0
        else { return nil }

        return value
    }

    public func removeLabel(_ label: String) {
        let file = directory.appending(path: label, directoryHint: .notDirectory)
        try? FileManager.default.removeItem(at: file)
    }

    public func purgeStaleLabels() {
        let manager = FileManager.default
        let files = (try? manager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        )) ?? []

        for file in files where !isAlive(pid(forLabel: file.lastPathComponent)) {
            try? manager.removeItem(at: file)
        }
    }

    private func isAlive(_ pid: Int32?) -> Bool {
        guard let pid else { return false }

        return kill(pid, 0) == 0 || errno == EPERM
    }
}
