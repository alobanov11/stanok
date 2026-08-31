import Foundation

enum GitProcessRunner {

    struct Result {

        let exitCode: Int32

        let standardOutput: Data

        let standardError: String
    }

    static func run(_ arguments: [String]) async -> Result {
        await withCheckedContinuation { continuation in
            GitProcessQueue.serial.async {
                let process = Process()
                process.executableURL = URL(filePath: "/usr/bin/env")
                process.environment = ToolEnvironment.current
                process.arguments = ["git"] + arguments

                let outputPipe = Pipe()
                let errorPipe = Pipe()
                process.standardOutput = outputPipe
                process.standardError = errorPipe

                do {
                    try process.run()
                    let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                    let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                    process.waitUntilExit()

                    let errorText = (String(data: errorData, encoding: .utf8) ?? "")
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
