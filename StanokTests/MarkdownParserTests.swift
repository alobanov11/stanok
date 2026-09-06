import AppKit
import Foundation
import Testing

@testable import StanokKit

struct MarkdownParserTests {

    private static let sample = """

    # Заголовок

    Абзац с **жирным**, *курсивом*, `кодом` и [ссылкой](https://example.com).

    ```swift
    let value = 1
    print(value)
    ```

    - первый
      - вложенный
    - [x] сделано

    1. один
    2. два

    > цитата

    | a | b |
    | - | - |
    | 1 | 2 |

    ---
    """

    @Test
    func headingsKeepTheirLevel() throws {
        let blocks = MarkdownParser.blocks(from: Self.sample)

        #expect(blocks.contains { block in
            if case let .heading(level) = block.kind { return level == 1 }

            return false
        })
    }

    @Test
    func fencedCodeKeepsEveryLine() throws {
        let blocks = MarkdownParser.blocks(from: Self.sample)
        let code = blocks.compactMap { block -> [[CodeToken]]? in
            guard case let .code(lines) = block.kind else { return nil }

            return lines
        }

        #expect(code.count == 1)
        #expect(code.first?.count == 2)
    }

    @Test
    func nestedListsGetTheirDepth() throws {
        let blocks = MarkdownParser.blocks(from: Self.sample)
        let depths = blocks.compactMap { block -> Int? in
            guard case let .bullet(depth) = block.kind else { return nil }

            return depth
        }

        #expect(depths == [1, 2, 1])
    }

    @Test
    func orderedListsKeepOrdinals() throws {
        let blocks = MarkdownParser.blocks(from: Self.sample)
        let ordinals = blocks.compactMap { block -> Int? in
            guard case let .numbered(ordinal, _) = block.kind else { return nil }

            return ordinal
        }

        #expect(ordinals == [1, 2])
    }

    @Test
    func tablesSplitIntoRows() throws {
        let blocks = MarkdownParser.blocks(from: Self.sample)
        let rows = blocks.compactMap { block -> Bool? in
            guard case let .tableRow(cells, isHeader) = block.kind else { return nil }

            #expect(cells.count == 2)

            return isHeader
        }

        #expect(rows == [true, false])
    }

    @Test
    func quotesAreMarked() throws {
        let blocks = MarkdownParser.blocks(from: Self.sample)

        #expect(blocks.contains { $0.isQuoted })
    }

    @Test
    func taskItemsShowTheirCheckbox() throws {
        let blocks = MarkdownParser.blocks(from: Self.sample)

        #expect(blocks.contains { String($0.text.characters).hasPrefix("☑") })
    }

    @Test
    func documentKeepsCodeAndHeadingStyle() throws {
        let document = MarkdownDocumentBuilder.document(
            blocks: MarkdownParser.blocks(from: Self.sample),
            size: 14,
            family: "",
            lineSpacing: 4,
            codeSize: 12,
            codeFamily: ""
        )

        #expect(document.text.string.contains("print(value)"))

        let heading = document.text.attributes(at: 0, effectiveRange: nil)
        let font = try #require(heading[.font] as? NSFont)

        #expect(font.pointSize > 14)
    }

    @Test
    func inlineFormattingSurvives() throws {
        let blocks = MarkdownParser.blocks(from: Self.sample)
        let paragraph = try #require(blocks.first { block in
            if case .paragraph = block.kind { return true }

            return false
        })

        let intents = paragraph.text.runs.compactMap(\.inlinePresentationIntent)

        #expect(intents.contains { $0.contains(.stronglyEmphasized) })
        #expect(intents.contains { $0.contains(.emphasized) })
        #expect(intents.contains { $0.contains(.code) })
        #expect(paragraph.text.runs.contains { $0.link != nil })
    }
}
