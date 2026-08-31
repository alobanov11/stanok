import Foundation
import Testing

import StanokKit

struct TerminalSessionTitleTests {

    @Test
    func displayNameFallsBackToBaseNameWithoutALiveTitle() {
        let session = TerminalSession(name: "shell")

        #expect(session.displayName == "shell")
    }

    @Test
    func displayNamePrefersTheLiveTitleWhenSet() {
        var session = TerminalSession(name: "shell")
        session.liveTitle = "npm run dev"

        #expect(session.displayName == "npm run dev")
    }

    @Test
    func encodingNeverIncludesTheLiveTitle() throws {
        var session = TerminalSession(name: "shell")
        session.liveTitle = "npm run dev"

        let data = try JSONEncoder().encode(session)
        let json = try #require(String(data: data, encoding: .utf8))

        #expect(!json.contains("liveTitle"))
        #expect(!json.contains("npm run dev"))
    }

    @Test
    func decodingAlwaysResetsTheLiveTitleEvenIfSomehowPresentOnDisk() throws {
        let json = """
        {
          "id" : "CAD281C8-F09A-44E8-960F-8F32C02A8F3D",
          "isPinned" : false,
          "liveTitle" : "stale from a previous run",
          "name" : "shell"
        }
        """

        let session = try JSONDecoder().decode(TerminalSession.self, from: Data(json.utf8))

        #expect(session.liveTitle == nil)
        #expect(session.displayName == "shell")
    }

    @Test
    func sanitizedSingleLineTrimsControlCharactersAndNewlines() {
        let raw = "npm\nrun\tdev\u{0007}"

        #expect(UntrustedText.sanitizedSingleLine(raw, maxLength: 60) == "npmrundev")
    }

    @Test
    func sanitizedSingleLineTruncatesLongTitlesWithAnEllipsis() {
        let raw = String(repeating: "a", count: 80)

        let result = UntrustedText.sanitizedSingleLine(raw, maxLength: 60)

        #expect(result == String(repeating: "a", count: 60) + "…")
    }
}
