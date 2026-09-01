import Foundation

enum ToolEnvironment {

    private enum Marker {

        static let open = "\u{1}"

        static let close = "\u{2}"
    }

    static let current: [String: String] = resolve()

    private static func resolve() -> [String: String] {
        var environment = ProcessInfo.processInfo.environment
        guard let path = loginShellPath(), !path.isEmpty else { return environment }

        environment["PATH"] = path

        return environment
    }

    private static func loginShellPath() -> String? {
        let shell = ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh"
        let process = Process()
        process.executableURL = URL(filePath: shell)
        process.arguments = ["-ilc", "printf '\(Marker.open)%s\(Marker.close)' \"$PATH\""]
        process.environment = ["HOME": NSHomeDirectory(), "SHELL": shell, "TERM": "dumb"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        process.standardInput = FileHandle.nullDevice

        do {
            try process.run()
        } catch {
            Log.terminal.error("cannot resolve tool path: \(error.localizedDescription)")
            return nil
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        return extract(String(data: data, encoding: .utf8))
    }

    static func extract(_ output: String?) -> String? {
        guard
            let output,
            let start = output.range(of: Marker.open),
            let end = output.range(of: Marker.close, range: start.upperBound..<output.endIndex)
        else { return nil }

        return String(output[start.upperBound..<end.lowerBound])
    }
}
