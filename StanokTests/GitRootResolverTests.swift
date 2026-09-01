import Foundation
import Testing

@testable import StanokKit

struct GitRootResolverTests {

    private static func makeTree(_ paths: [String]) throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appending(path: "roots-\(UUID().uuidString)", directoryHint: .isDirectory)

        for path in paths {
            try FileManager.default.createDirectory(
                at: root.appending(path: path),
                withIntermediateDirectories: true
            )
        }

        return root
    }

    @Test
    func aDirectoryUnderAKnownRootInheritsIt() throws {
        let tree = try Self.makeTree(["app/.git", "app/Sources"])
        defer { try? FileManager.default.removeItem(at: tree) }

        let root = tree.appending(path: "app").path(percentEncoded: false)
        let directory = tree.appending(path: "app/Sources").path(percentEncoded: false)

        #expect(GitRootResolver.inherited(for: directory, from: [root]) == GitRootResolver.normalized(root))
    }

    @Test
    func aTrailingSlashDoesNotBreakTheMatch() throws {
        let tree = try Self.makeTree(["app/.git", "app/Sources"])
        defer { try? FileManager.default.removeItem(at: tree) }

        let root = tree.appending(path: "app").path(percentEncoded: false)
        let directory = tree.appending(path: "app/Sources", directoryHint: .isDirectory)
            .path(percentEncoded: false)

        #expect(GitRootResolver.inherited(for: directory, from: [root + "/"]) != nil)
    }

    @Test
    func aSubmoduleIsNotInheritedFromItsParent() throws {
        let tree = try Self.makeTree(["app/.git", "app/Vendor/lib/.git", "app/Vendor/lib/Sources"])
        defer { try? FileManager.default.removeItem(at: tree) }

        let parent = tree.appending(path: "app").path(percentEncoded: false)
        let inside = tree.appending(path: "app/Vendor/lib/Sources").path(percentEncoded: false)

        #expect(GitRootResolver.inherited(for: inside, from: [parent]) == nil)

        let nested = tree.appending(path: "app/Vendor/lib").path(percentEncoded: false)
        #expect(
            GitRootResolver.inherited(for: inside, from: [parent, nested])
                == GitRootResolver.normalized(nested)
        )
    }
}
