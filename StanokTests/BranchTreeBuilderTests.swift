import Foundation
import Testing

import StanokKit

@MainActor
struct BranchTreeBuilderTests {

    private enum Fixture {

        static func local(_ name: String, isCurrent: Bool = false) -> GitBranchRef {
            GitBranchRef(
                fullName: "refs/heads/\(name)",
                displayName: name,
                kind: .local,
                isCurrent: isCurrent
            )
        }

        static func remote(_ remoteName: String, _ name: String) -> GitBranchRef {
            GitBranchRef(
                fullName: "refs/remotes/\(remoteName)/\(name)",
                displayName: name,
                kind: .remote,
                remoteName: remoteName
            )
        }
    }

    @Test
    func slashSplitsIntoANestedFolderWithALeaf() throws {
        let name = "feature/SC-471-questions-row-cap"
        let root = BranchTreeBuilder.build(from: [Fixture.local(name)])
        let branches = try branchesNode(root)

        #expect(branches.children.count == 1)

        let featureFolder = branches.children[0]
        #expect(featureFolder.name == "feature")
        #expect(featureFolder.isFolder)
        #expect(featureFolder.children.count == 1)

        let leaf = featureFolder.children[0]
        #expect(leaf.name == "SC-471-questions-row-cap")
        #expect(!leaf.isFolder)
        #expect(leaf.ref?.fullName == "refs/heads/\(name)")
    }

    @Test
    func splittingIsRecursiveAcrossMultipleLevels() throws {
        let root = BranchTreeBuilder.build(from: [Fixture.local("a/b/c")])
        let branches = try branchesNode(root)

        #expect(branches.depth == 1)

        let folderA = branches.children[0]
        #expect(folderA.name == "a")
        #expect(folderA.depth == 2)
        #expect(folderA.isFolder)

        let folderB = folderA.children[0]
        #expect(folderB.name == "b")
        #expect(folderB.depth == 3)
        #expect(folderB.isFolder)

        let leafC = folderB.children[0]
        #expect(leafC.name == "c")
        #expect(leafC.depth == 4)
        #expect(!leafC.isFolder)
    }

    @Test
    func foldersSortBeforeLeavesRegardlessOfAlphabeticalOrder() throws {
        let root = BranchTreeBuilder.build(from: [
            Fixture.local("aaa"),
            Fixture.local("zzz/nested")
        ])
        let branches = try branchesNode(root)

        #expect(branches.children.map(\.name) == ["zzz", "aaa"])
        #expect(branches.children[0].isFolder)
        #expect(!branches.children[1].isFolder)
    }

    @Test
    func siblingsAtTheSameLevelSortAlphabetically() throws {
        let root = BranchTreeBuilder.build(from: [
            Fixture.local("charlie/x"),
            Fixture.local("alpha/x"),
            Fixture.local("bravo/x")
        ])
        let branches = try branchesNode(root)

        #expect(branches.children.map(\.name) == ["alpha", "bravo", "charlie"])
    }

    @Test
    func branchWithNoSlashIsALeafDirectlyUnderBranches() throws {
        let root = BranchTreeBuilder.build(from: [Fixture.local("develop")])
        let branches = try branchesNode(root)

        #expect(branches.children.count == 1)
        #expect(branches.children[0].name == "develop")
        #expect(!branches.children[0].isFolder)
        #expect(branches.children[0].depth == 2)
    }

    @Test
    func remoteBranchesNestUnderTheRemoteNameThenSplitFurther() throws {
        let root = BranchTreeBuilder.build(from: [Fixture.remote("origin", "feature/foo")])
        let remotes = try remotesNode(root)

        #expect(remotes.children.count == 1)

        let originFolder = remotes.children[0]
        #expect(originFolder.name == "origin")
        #expect(originFolder.depth == 2)
        #expect(originFolder.isFolder)

        let featureFolder = originFolder.children[0]
        #expect(featureFolder.name == "feature")
        #expect(featureFolder.depth == 3)

        let leaf = featureFolder.children[0]
        #expect(leaf.name == "foo")
        #expect(leaf.depth == 4)
        #expect(leaf.ref?.remoteName == "origin")
    }

    @Test
    func branchesStartsExpandedAndOtherFoldersStartCollapsed() throws {
        let root = BranchTreeBuilder.build(from: [
            Fixture.local("feature/foo"),
            Fixture.remote("origin", "feature/foo")
        ])
        let branches = try branchesNode(root)
        let remotes = try remotesNode(root)

        #expect(branches.isExpanded)
        #expect(!remotes.isExpanded)
        #expect(!branches.children[0].isExpanded)
    }

    @Test
    func expansionStateSurvivesARebuild() throws {
        let refs = [Fixture.local("feature/foo"), Fixture.remote("origin", "bar")]
        let firstRoot = BranchTreeBuilder.build(from: refs)

        let featureFolder = try branchesNode(firstRoot).children[0]
        featureFolder.toggle()

        let firstRemotes = try remotesNode(firstRoot)
        firstRemotes.toggle()

        #expect(featureFolder.isExpanded)
        #expect(firstRemotes.isExpanded)

        let secondRoot = BranchTreeBuilder.build(from: refs, reusing: firstRoot)

        #expect(try branchesNode(secondRoot).children[0].isExpanded)
        #expect(try remotesNode(secondRoot).isExpanded)
    }

    @Test
    func newlyDiscoveredFoldersStartCollapsedOnRebuild() throws {
        let firstRoot = BranchTreeBuilder.build(from: [Fixture.local("feature/foo")])
        let secondRoot = BranchTreeBuilder.build(
            from: [Fixture.local("feature/foo"), Fixture.local("bugfix/bar")],
            reusing: firstRoot
        )

        let bugfixFolder = try branchesNode(secondRoot).children.first { $0.name == "bugfix" }
        #expect(bugfixFolder?.isExpanded == false)
    }

    private func branchesNode(_ root: BranchNode) throws -> BranchNode {
        try #require(root.children.first { $0.id == BranchTreeBuilder.branchesID })
    }

    private func remotesNode(_ root: BranchNode) throws -> BranchNode {
        try #require(root.children.first { $0.id == BranchTreeBuilder.remotesID })
    }
}
