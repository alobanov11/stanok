import Foundation
import Testing

@testable import StanokAgents

struct ClaudeSessionRecordScannerTests {

    private static func lines(_ lines: [String]) -> Data {
        Data(lines.joined(separator: "\n").utf8)
    }

    @Test
    func titleFoundInHead() {
        let sessionID = UUID().uuidString
        let data = Self.lines([
            #"{"type":"user","sessionId":"\#(sessionID)","message":"hi"}"#,
            #"{"type":"ai-title","sessionId":"\#(sessionID)","aiTitle":"Fix the login bug"}"#
        ])

        let result = ClaudeSessionRecordScanner.scan(data)

        #expect(result.title == "Fix the login bug")
        #expect(result.sessionID == sessionID)
    }

    @Test
    func noTitlePresent() {
        let sessionID = UUID().uuidString
        let data = Self.lines([
            #"{"type":"user","sessionId":"\#(sessionID)","message":"hi"}"#
        ])

        let result = ClaudeSessionRecordScanner.scan(data)

        #expect(result.title == nil)
        #expect(result.sessionID == sessionID)
    }

    @Test
    func multipleTitlesLastWins() {
        let sessionID = UUID().uuidString
        let data = Self.lines([
            #"{"type":"ai-title","sessionId":"\#(sessionID)","aiTitle":"First title"}"#,
            #"{"type":"user","sessionId":"\#(sessionID)","message":"more context"}"#,
            #"{"type":"ai-title","sessionId":"\#(sessionID)","aiTitle":"Second title"}"#
        ])

        let result = ClaudeSessionRecordScanner.scan(data)

        #expect(result.title == "Second title")
    }

    @Test
    func corruptedJSONIsIgnored() {
        let sessionID = UUID().uuidString
        let data = Self.lines([
            "{this is not valid json",
            #"{"type":"ai-title","sessionId":"\#(sessionID)","aiTitle":"Recovered title"}"#
        ])

        let result = ClaudeSessionRecordScanner.scan(data)

        #expect(result.title == "Recovered title")
    }

    @Test
    func lineTooLongIsIgnored() {
        let sessionID = UUID().uuidString
        let hugeValue = String(repeating: "x", count: 128 * 1024)
        let data = Self.lines([
            #"{"type":"ai-title","sessionId":"\#(sessionID)","aiTitle":"\#(hugeValue)"}"#,
            #"{"type":"ai-title","sessionId":"\#(sessionID)","aiTitle":"Short title"}"#
        ])

        let result = ClaudeSessionRecordScanner.scan(data)

        #expect(result.title == "Short title")
    }

    @Test
    func firstCwdIsCaptured() {
        let data = Self.lines([
            #"{"type":"queue-operation","timestamp":"2026-08-01T10:00:00Z"}"#,
            #"{"type":"attachment","cwd":"/Users/test/first"}"#,
            #"{"type":"attachment","cwd":"/Users/test/second"}"#
        ])

        let result = ClaudeSessionRecordScanner.scan(data)

        #expect(result.cwd == "/Users/test/first")
    }

    @Test
    func firstTimestampIsCaptured() {
        let data = Self.lines([
            #"{"type":"queue-operation","timestamp":"2026-08-01T10:00:00Z"}"#,
            #"{"type":"attachment","timestamp":"2026-08-02T10:00:00Z"}"#
        ])

        let result = ClaudeSessionRecordScanner.scan(data)

        var expected = DateComponents()
        expected.year = 2026
        expected.month = 8
        expected.day = 1
        expected.hour = 10
        expected.timeZone = TimeZone(identifier: "UTC")
        let expectedDate = Calendar(identifier: .gregorian).date(from: expected)

        #expect(result.firstTimestamp == expectedDate)
    }

    @Test
    func firstUserMessageTextIsCapturedAsFallback() {
        let data = Self.lines([
            #"{"type":"user","isSidechain":false,"message":{"role":"user","content":"Fix bug"}}"#
        ])

        let result = ClaudeSessionRecordScanner.scan(data)

        #expect(result.title == nil)
        #expect(result.firstUserMessageText == "Fix bug")
    }

    @Test
    func sidechainUserMessageIsIgnoredForFallback() {
        let data = Self.lines([
            #"{"type":"user","isSidechain":true,"message":{"role":"user","content":"Internal"}}"#
        ])

        let result = ClaudeSessionRecordScanner.scan(data)

        #expect(result.firstUserMessageText == nil)
    }

}
