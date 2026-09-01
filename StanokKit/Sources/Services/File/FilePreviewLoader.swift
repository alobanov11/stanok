import Foundation

enum FilePreviewLoader {

    private enum Source {

        case text(String)
        case rejected(FilePreview.Content)
    }

    private enum Limit {

        static let size = 2 * 1024 * 1024
        static let lines = 5000
    }

    private static let markdownExtensions: Set<String> = ["md", "markdown", "mdown", "mkd"]

    static func load(_ url: URL, source: ReviewSource = .worktree) async -> FilePreview {
        var preview = await Task.detached(priority: .userInitiated) { read(url) }.value
        guard !Task.isCancelled, case .code = preview.content else { return preview }

        preview.changes = await GitLineChanges.load(for: url, source: source)
        return preview
    }

    // Почему: текст коммита и его дифф должны быть одной ревизией, иначе номера строк врут
    static func load(_ url: URL, in root: String, path: String, sha: String) async -> FilePreview {
        let blob = await GitProcessRunner.run([
            "--no-optional-locks", "-C", root, "show", "\(sha):\(path)"
        ])

        guard blob.exitCode == 0, let text = decode(blob.standardOutput) else {
            return await load(url, source: .commit(sha))
        }

        var preview = await Task.detached(priority: .userInitiated) {
            read(url, text: text)
        }.value

        guard !Task.isCancelled, case .code = preview.content else { return preview }

        preview.changes = await GitLineChanges.load(for: url, source: .commit(sha))

        return preview
    }

    private static func decode(_ data: Data) -> String? {
        if data.starts(with: [0xFF, 0xFE]) {
            return String(data: data, encoding: .utf16LittleEndian)
        }

        if data.starts(with: [0xFE, 0xFF]) {
            return String(data: data, encoding: .utf16BigEndian)
        }

        guard !data.contains(0) else { return nil }

        return String(data: data, encoding: .utf8)
    }

    private static func missing(_ url: URL) -> FilePreview.Content {
        FileManager.default.fileExists(atPath: url.path(percentEncoded: false))
            ? .unreadable
            : .failed("Файл не найден")
    }

    private static func source(of url: URL, isRegular: Bool) -> Source {
        guard isRegular else { return .rejected(missing(url)) }

        guard let handle = try? FileHandle(forReadingFrom: url) else {
            return .rejected(.failed("Нет доступа к файлу"))
        }

        defer { try? handle.close() }

        guard let data = try? handle.read(upToCount: Limit.size + 1) else {
            return .rejected(.failed("Не удалось прочитать файл"))
        }

        guard data.count <= Limit.size else { return .rejected(.tooLarge) }
        guard let text = decode(data) else { return .rejected(.unreadable) }

        return .text(text)
    }

    private static func read(_ url: URL, text: String) -> FilePreview {
        let size = Int64(text.utf8.count)

        if markdownExtensions.contains(url.pathExtension.lowercased()) {
            let blocks = MarkdownParser.blocks(from: text, baseURL: url.deletingLastPathComponent())

            return FilePreview(
                url: url,
                content: .markdown(blocks),
                size: size,
                kind: "Файл",
                modified: nil,
                isTruncated: false
            )
        }

        let lines = text.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline)
        let truncated = lines.count > Limit.lines
        let shown = truncated ? lines.prefix(Limit.lines).joined(separator: "\n") : text

        return FilePreview(
            url: url,
            content: .code(CodeHighlighter.lines(shown, language: url.pathExtension.lowercased())),
            size: size,
            kind: "Файл",
            modified: nil,
            isTruncated: truncated
        )
    }

    private static func read(_ url: URL) -> FilePreview {
        let values = try? url.resourceValues(forKeys: [
            .fileSizeKey, .contentModificationDateKey, .contentTypeKey, .isRegularFileKey
        ])
        let size = Int64(values?.fileSize ?? 0)
        let kind = values?.contentType?.localizedDescription ?? "Файл"
        let modified = values?.contentModificationDate

        func preview(_ content: FilePreview.Content, truncated: Bool) -> FilePreview {
            FilePreview(
                url: url,
                content: content,
                size: size,
                kind: kind,
                modified: modified,
                isTruncated: truncated
            )
        }

        switch source(of: url, isRegular: values?.isRegularFile == true) {
        case let .rejected(content):
            return preview(content, truncated: false)

        case let .text(text):
            if markdownExtensions.contains(url.pathExtension.lowercased()) {
                let baseURL = url.deletingLastPathComponent()
                let blocks = MarkdownParser.blocks(from: text, baseURL: baseURL)

                return preview(.markdown(blocks), truncated: false)
            }

            let lines = text.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline)
            let truncated = lines.count > Limit.lines
            let shown = truncated ? lines.prefix(Limit.lines).joined(separator: "\n") : text

            return preview(
                .code(CodeHighlighter.lines(shown, language: url.pathExtension.lowercased())),
                truncated: truncated
            )
        }
    }
}
