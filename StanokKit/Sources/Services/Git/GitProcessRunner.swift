import Foundation

enum GitProcessRunner {

    struct Result {

        let exitCode: Int32
        let standardOutput: Data
        let standardError: String
    }

    private final class Buffer: @unchecked Sendable {

        var data = Data()
    }

    static func run(_ arguments: [String]) async -> Result {
        let environment = ToolEnvironment.current

        return await withCheckedContinuation { continuation in
            GitProcessQueue.serial.async {
                let process = Process()
                process.executableURL = URL(filePath: "/usr/bin/env")
                process.environment = environment
                process.standardInput = FileHandle.nullDevice
                process.arguments = ["git"] + arguments

                let outputPipe = Pipe()
                let errorPipe = Pipe()
                process.standardOutput = outputPipe
                process.standardError = errorPipe

                do {
                    try process.run()

                    // Почему: git встаёт навсегда, если stderr не читать вместе с stdout
                    let errors = Buffer()
                    let group = DispatchGroup()
                    DispatchQueue.global(qos: .utility).async(group: group) {
                        errors.data = errorPipe.fileHandleForReading.readDataToEndOfFile()
                    }

                    let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                    group.wait()
                    process.waitUntilExit()

                    let errorText = (String(data: errors.data, encoding: .utf8) ?? "")
                        .trimmingCharacters(in: .whitespacesAndNewlines)

                    continuation.resume(returning: Result(
                        exitCode: process.terminationStatus,
                        standardOutput: outputData,
                        standardError: errorText
                    ))
                } catch {
                    continuation.resume(returning: Result(
                        exitCode: -1,
                        standardOutput: Data(),
                        standardError: error.localizedDescription
                    ))
                }
            }
        }
    }
}
