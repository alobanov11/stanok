import Foundation
import Testing

import StanokKit

struct DefaultConfigTests {

    @Test
    func seedsAShellInitScriptThatPassesAZshSyntaxCheck() throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "stanok-default-config-tests-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }

        setenv("XDG_CONFIG_HOME", directory.path(percentEncoded: false), 1)
        defer { unsetenv("XDG_CONFIG_HOME") }

        DefaultConfig.seed()

        let script = AppPaths.shellInit
        #expect(FileManager.default.fileExists(atPath: script.path(percentEncoded: false)))

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-n", script.path(percentEncoded: false)]
        let pipe = Pipe()
        process.standardError = pipe
        try process.run()
        process.waitUntilExit()

        let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)
        #expect(process.terminationStatus == 0, "\(output ?? "")")
    }
}
