import Foundation
import Markdown

enum MarkdownInline {

    static func text(of markup: any Markup, baseURL: URL?) -> AttributedString {
        var result = AttributedString()

        for child in markup.children {
            result.append(inline(child, baseURL: baseURL))
        }

        return result
    }
}

private extension MarkdownInline {

    static func inline(_ markup: any Markup, baseURL: URL?) -> AttributedString {
        switch markup {
        case let text as Markdown.Text:
            AttributedString(text.string)

        case let code as InlineCode:
            marked(AttributedString(code.code), with: .code)

        case let strong as Strong:
            marked(text(of: strong, baseURL: baseURL), with: .stronglyEmphasized)

        case let emphasis as Emphasis:
            marked(text(of: emphasis, baseURL: baseURL), with: .emphasized)

        case let strikethrough as Strikethrough:
            marked(text(of: strikethrough, baseURL: baseURL), with: .strikethrough)

        case let link as Markdown.Link:
            linked(text(of: link, baseURL: baseURL), to: link.destination, baseURL: baseURL)

        case let image as Markdown.Image:
            linked(
                marked(AttributedString(image.plainText), with: .emphasized),
                to: image.source,
                baseURL: baseURL
            )

        case is SoftBreak:
            AttributedString(" ")

        case is LineBreak:
            AttributedString("\n")

        case let html as InlineHTML:
            AttributedString(html.rawHTML)

        default:
            text(of: markup, baseURL: baseURL)
        }
    }

    static func marked(
        _ text: AttributedString,
        with intent: InlinePresentationIntent
    ) -> AttributedString {
        var result = text

        for range in result.runs.map(\.range) {
            var merged = result[range].inlinePresentationIntent ?? []
            merged.insert(intent)
            result[range].inlinePresentationIntent = merged
        }

        return result
    }

    static func linked(
        _ text: AttributedString,
        to destination: String?,
        baseURL: URL?
    ) -> AttributedString {
        guard
            let destination,
            let url = URL(string: destination, relativeTo: baseURL)
        else { return text }

        var result = text
        result.link = url

        return result
    }
}
