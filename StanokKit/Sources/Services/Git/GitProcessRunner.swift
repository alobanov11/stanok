import Foundation

enum GitProcessRunner {

    struct Result {

        let exitCode: Int32
        let standardOutput: Data
        let standardError: String
    }

    enum Limit {

        static let output = 8 * 1024 * 1024
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
        "cat-file", "for-each-ref", "merge-base", "check-ignore"
    ]

    static func run(_ arguments: [String], limit: Int = Limit.output) async -> Result {
        guard isReadOnly(arguments) else {
            return await start(arguments, box: Handle(), limit: limit)
        }

        // Почему: отменённая задача иначе занимает единственную очередь до конца процесса
        let box = Handle()

        return await withTaskCancellationHandler {
            await start(arguments, box: box, limit: limit)
        } onCancel: {
            box.terminate()
        }
    }

    // Почему: у git есть глобальные флаги со значениями, подкоманда идёт уже за ними
    static func isReadOnly(_ arguments: [String]) -> Bool {
        var index = arguments.startIndex

        while index < arguments.endIndex {
            let argument = arguments[index]

            if argument == "-C" || argument == "-c" {
                index = arguments.index(index, offsetBy: 2)
                continue
            }

            guard argument.hasPrefix("-") else { break }

            index = arguments.index(after: index)
        }

        guard index < arguments.endIndex else { return false }

        let command = arguments[index]
        let tail = arguments[arguments.index(after: index)...]

        if command == "worktree" { return tail.first == "list" }
        if command == "config" { return tail.contains { $0 == "--get" || $0 == "--list" } }

        return readOnly.contains(command)
    }

    // Почему: вывод читаем порциями, иначе гигантский дифф целиком поднимается в память
    private static func read(_ handle: FileHandle, limit: Int) -> Data {
        var data = Data()

        while true {
            let chunk = handle.availableData
            guard !chunk.isEmpty else { break }

            if data.count < limit { data.append(chunk) }
        }

        return data
    }

    private static func start(_ arguments: [String], box: Handle, limit: Int) async -> Result {
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

                    let outputData = read(outputPipe.fileHandleForReading, limit: limit)
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
