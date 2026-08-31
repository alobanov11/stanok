import Foundation
import Testing

@testable import StanokKit

struct GitLineChangesTests {

    @Test
    func anInsertionMarksTheNewLinesAsAdded() {
        let changes = GitLineChanges.parse("@@ -12,0 +13,3 @@\n+one\n+two\n+three")

        #expect(changes == [13: .added, 14: .added, 15: .added])
    }

    @Test
    func aReplacementMarksTheNewLinesAsModified() {
        let changes = GitLineChanges.parse("@@ -12,2 +13,2 @@\n-old\n-old\n+new\n+new")

        #expect(changes == [13: .modified, 14: .modified])
    }

    @Test
    func aDeletionLeavesOneMarkerWhereTheLinesWere() {
        let changes = GitLineChanges.parse("@@ -12,3 +11,0 @@\n-gone")

        #expect(changes == [11: .removed])
    }

    @Test
    func aHunkWithoutACountCoversASingleLine() {
        let changes = GitLineChanges.parse("@@ -5 +5 @@\n-old\n+new")

        #expect(changes == [5: .modified])
    }

    @Test
    func severalHunksAreAllReported() {
        let diff = """
        diff --git a/file b/file
        --- a/file
        +++ b/file
        @@ -1,0 +2,1 @@ func run() {
        +added
        @@ -20,1 +30,1 @@
        -old
        +new
        """

        #expect(GitLineChanges.parse(diff) == [2: .added, 30: .modified])
    }

    @Test
    func textWithoutHunksChangesNothing() {
        #expect(GitLineChanges.parse("").isEmpty)
    }
}
