import Foundation
import Testing

import StanokKit

struct GitCommandOutcomeTests {

    @Test
    func succeedsWithInformationalStderrOnly() {
        let outcome = GitCommandOutcome.make(
            exitCode: 0,
            standardOutput: Data(),
            standardError: "Already on 'main'"
        )

        #expect(outcome.succeeded)
        #expect(outcome.message == "Already on 'main'")
    }

    @Test
    func succeedsWithStdoutMessage() {
        let outcome = GitCommandOutcome.make(
            exitCode: 0,
            standardOutput: Data("Deleted branch dummy (was ed4df14).\n".utf8),
            standardError: ""
        )

        #expect(outcome.succeeded)
        #expect(outcome.message == "Deleted branch dummy (was ed4df14).")
    }

    @Test
    func failsAndPreservesMultilineStderr() {
        let stderr = """
        error: the branch 'dummy2' is not fully merged
        hint: If you are sure you want to delete it, run 'git branch -D dummy2'
        hint: Disable this message with "git config set advice.forceDeleteBranch false"
        """
        let outcome = GitCommandOutcome.make(
            exitCode: 1,
            standardOutput: Data(),
            standardError: stderr
        )

        #expect(!outcome.succeeded)
        #expect(outcome.message == stderr)
    }

    @Test
    func failsOnInvalidRefFormat() {
        let outcome = GitCommandOutcome.make(
            exitCode: 128,
            standardOutput: Data(),
            standardError: "fatal: 'bad name' is not a valid branch name"
        )

        #expect(!outcome.succeeded)
        #expect(outcome.message == "fatal: 'bad name' is not a valid branch name")
    }

    @Test
    func succeedsWithEmptyMessageWhenBothStreamsAreEmpty() {
        let outcome = GitCommandOutcome.make(exitCode: 0, standardOutput: Data(), standardError: "")

        #expect(outcome.succeeded)
        #expect(outcome.message.isEmpty)
    }
}
