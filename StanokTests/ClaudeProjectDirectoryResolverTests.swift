import Foundation
import Testing

@testable import StanokAgents

struct ClaudeProjectDirectoryResolverTests {

    @Test
    func encodesTheOwnersDocumentedExample() throws {
        let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }

        let expected = "-Users-tom-Projects-sorok-sorok-web-app"
        let directory = root.appending(path: expected)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let projectURL = URL(fileURLWithPath: "/Users/tom/Projects/sorok/sorok-web-app")
        let resolved = ClaudeProjectDirectoryResolver.resolve(projectURL: projectURL, root: root)

        let resolvedPath = resolved?.path(percentEncoded: false)
        #expect(resolvedPath?.hasPrefix(directory.path(percentEncoded: false)) == true)
    }

    @Test
    func returnsNilWhenNoCandidateExists() {
        let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        let projectURL = URL(fileURLWithPath: "/Users/tom/Projects/unknown")

        #expect(ClaudeProjectDirectoryResolver.resolve(projectURL: projectURL, root: root) == nil)
    }
}
