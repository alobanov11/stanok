import Foundation
import Markdown

enum MarkdownParser {

    static func blocks(from markdown: String, baseURL: URL? = nil) -> [MarkdownBlock] {
        let document = Document(parsing: markdown, options: [.disableSourcePosOpts])
        var builder = MarkdownBlockBuilder(baseURL: baseURL)

        for child in document.children {
            builder.append(child)
        }

        return builder.blocks
    }
}
