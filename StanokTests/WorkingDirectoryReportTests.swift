import Foundation
import Testing

@testable import StanokKit

struct WorkingDirectoryReportTests {

    private static func temporaryDirectory() throws -> URL {
        let name = "working-directory-report-tests-\(UUID().uuidString)"
        let directory = FileManager.default.temporaryDirectory
            .appending(path: name, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    @Test
    func normalizedPathStripsATrailingSlash() {
        let normalized = WorkingDirectoryReport.normalizedPath("/Users/tom/Projects/foo/")

        #expect(normalized == "/Users/tom/Projects/foo")
    }

    @Test
    func normalizedPathLeavesAPathWithoutATrailingSlashAlone() {
        let normalized = WorkingDirectoryReport.normalizedPath("/Users/tom/Projects/foo")

        #expect(normalized == "/Users/tom/Projects/foo")
    }

    @Test
    func normalizedPathLeavesTheRootSlashAlone() {
        #expect(WorkingDirectoryReport.normalizedPath("/") == "/")
    }

    @Test
    func urlsRejectsANonAbsolutePayload() {
        #expect(WorkingDirectoryReport.urls(fromPwd: "relative/path") == nil)
        #expect(WorkingDirectoryReport.urls(fromPwd: "") == nil)
    }

    @Test
    func urlsReportsTheLogicalPathAsGivenWhenThereIsNoSymlink() throws {
        let directory = try Self.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let path = directory.path(percentEncoded: false)

        let urls = try #require(WorkingDirectoryReport.urls(fromPwd: path))

        #expect(urls.reported.path(percentEncoded: false) == path)
        #expect(urls.identity.path(percentEncoded: false) == path)
    }

    @Test
    func urlsResolvesTheIdentityThroughASymlinkKeepingTheReportedPathLogical() throws {
        let base = try Self.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: base) }

        let target = base.appending(path: "real", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: target, withIntermediateDirectories: true)

        let link = base.appending(path: "link", directoryHint: .isDirectory)
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: target)
        let linkPath = link.path(percentEncoded: false)

        let urls = try #require(WorkingDirectoryReport.urls(fromPwd: linkPath))

        let expectedReportedPath = WorkingDirectoryReport.normalizedPath(linkPath)
        let expectedIdentityPath = WorkingDirectoryReport.normalizedPath(
            target.resolvingSymlinksInPath().path(percentEncoded: false)
        )
        let reportedPath = urls.reported.path(percentEncoded: false)
        let identityPath = urls.identity.path(percentEncoded: false)

        #expect(reportedPath == expectedReportedPath)
        #expect(identityPath == expectedIdentityPath)
        #expect(identityPath != reportedPath)
    }

}
