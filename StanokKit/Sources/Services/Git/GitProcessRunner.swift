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

    private final class Handle: @unchecked Sendable {

        private let lock = NSLock()

        private var process: Process?
        private var isCancelled = false

        func adopt(_ process: Process) -> Bool {
            lock.lock()
            defer { lock.unlock() }

            guard !isCancelled else { return false }

            self.process = process

            return true
        }

        // Почему: отмена могла прийти между adopt и run, поэтому старт подтверждается отдельно
        func confirm() {
            lock.lock()
            let cancelled = isCancelled
            let running = process
            lock.unlock()

            guard cancelled, let running, running.isRunning else { return }

            running.terminate()
        }

        func terminate() {
            lock.lock()
            let running = process
            isCancelled = true
            lock.unlock()

            guard let running, running.isRunning else { return }

            running.terminate()
        }
    }

    // Почему: читающие команды можно обрывать, меняющие дерево — только доводить до конца
    static let readOnly: Set<String> = [
        "status", "diff", "diff-tree", "show", "log", "rev-parse", "rev-list", "ls-files",
        "cat-file", "for-each-ref", "merge-base", "worktree", "config", "check-ignore"
    ]

    static func run(_ arguments: [String]) async -> Result {
        let command = arguments.first { !$0.hasPrefix("-") && $0 != "-C" } ?? ""
        guard readOnly.contains(command) else { return await start(arguments, box: Handle()) }

        // Почему: отменённая задача иначе занимает единственную очередь до конца процесса
        let box = Handle()

        return await withTaskCancellationHandler {
            await start(arguments, box: box)
        } onCancel: {
            box.terminate()
        }
    }

    private static func start(_ arguments: [String], box: Handle) async -> Result {
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
                    guard box.adopt(process) else {
                        continuation.resume(returning: Result(
                            exitCode: -1,
                            standardOutput: Data(),
                            standardError: "cancelled"
                        ))
                        return
                    }

                    try process.run()
                    box.confirm()

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
