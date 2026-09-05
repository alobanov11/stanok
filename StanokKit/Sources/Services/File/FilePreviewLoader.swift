import Foundation

enum FilePreviewLoader {

    enum Rendering {

        case rich
        case plain
    }

    private enum Source {

        case text(String)
        case rejected(FilePreview.Content)
    }

    private enum Limit {

        static let size = 2 * 1024 * 1024
        static let image = 16 * 1024 * 1024
        static let lines = 5000
    }

    private static let markdownExtensions: Set<String> = ["md", "markdown", "mdown", "mkd"]

    private static let imageExtensions: Set<String> = [
        "png", "jpg", "jpeg", "gif", "heic", "heif", "webp", "tiff", "tif", "bmp", "ico", "svg"
    ]

    static func load(
        _ url: URL,
        source: ReviewSource = .worktree,
        rendering: Rendering = .rich,
        root: String? = nil
    ) async -> FilePreview {
        var preview = await Task.detached(priority: .userInitiated) {
            read(url, rendering: rendering)
        }.value

        // Почему: у картинки в ревью показываем и прежнюю версию, взятую из индекса репозитория
        if case let .image(image) = preview.content {
            return await imagePreview(preview, image: image, url: url, source: source, root: root)
        }

        guard !Task.isCancelled, case .code = preview.content else { return preview }

        preview.changes = await GitLineChanges.load(for: url, source: source, root: root)

        return preview
    }

    static func imagePreview(
        _ preview: FilePreview,
        image: ImagePreview,
        url: URL,
        source: ReviewSource,
        root: String?
    ) async -> FilePreview {
        guard let root, let path = relativePath(of: url, in: root) else { return preview }

        let revision: String = switch source {
        case .worktree: "HEAD"
        case let .commit(sha): sha + "^"
        }

        let old = await blob(root: root, revision: revision, path: path)

        return FilePreview(
            url: preview.url,
            content: .image(ImagePreview(new: image.new, old: old)),
            size: preview.size,
            kind: preview.kind,
            modified: preview.modified,
            isTruncated: false
        )
    }

    // Почему: текст коммита и его дифф должны быть одной ревизией, иначе номера строк врут
    static func load(
        _ url: URL,
        in root: String,
        path: String,
        sha: String,
        rendering: Rendering = .rich
    ) async -> FilePreview {
        if imageExtensions.contains(url.pathExtension.lowercased()) {
            return await commitImage(url, in: root, path: path, sha: sha)
        }

        let measure = await GitProcessRunner.run([
            "--no-optional-locks", "-C", root, "cat-file", "-s", "\(sha):\(path)"
        ])
        guard measure.exitCode == 0 else {
            return rejected(url, content: .failed("Файла нет в этом коммите"))
        }

        let size = String(data: measure.standardOutput, encoding: .utf8)
            .flatMap { Int($0.trimmingCharacters(in: .whitespacesAndNewlines)) } ?? 0

        guard size <= Limit.size else {
            return rejected(url, content: .tooLarge, size: Int64(size))
        }

        let blob = await GitProcessRunner.run([
            "--no-optional-locks", "-C", root, "show", "\(sha):\(path)"
        ])

        // Почему: подменить содержимое коммита рабочей копией — значит соврать про ревизию
        guard blob.exitCode == 0 else {
            return rejected(url, content: .failed("Не удалось прочитать файл из коммита"))
        }

        let output = blob.standardOutput
        let decoded = await Task.detached(priority: .userInitiated) { decode(output) }.value

        guard let text = decoded else {
            return rejected(url, content: .unreadable)
        }

        var preview = await Task.detached(priority: .userInitiated) {
            read(url, text: text, rendering: rendering)
        }.value

        guard !Task.isCancelled, case .code = preview.content else { return preview }

        preview.changes = await GitLineChanges.load(for: url, source: .commit(sha), root: root)

        return preview
    }

    private static func commitImage(
        _ url: URL,
        in root: String,
        path: String,
        sha: String
    ) async -> FilePreview {
        let new = await blob(root: root, revision: sha, path: path)
        let old = await blob(root: root, revision: sha + "^", path: path)

        guard new != nil || old != nil else {
            return rejected(url, content: .failed("Файла нет в этом коммите"))
        }

        return FilePreview(
            url: url,
            content: .image(ImagePreview(new: new, old: old)),
            size: Int64(new?.count ?? old?.count ?? 0),
            kind: "Изображение",
            modified: nil,
            isTruncated: false
        )
    }

    private static func relativePath(of url: URL, in root: String) -> String? {
        let path = url.standardizedFileURL.path(percentEncoded: false)
        let base = root.hasSuffix("/") ? root : root + "/"
        guard path.hasPrefix(base) else { return nil }

        return String(path.dropFirst(base.count))
    }

    private static func blob(root: String, revision: String, path: String) async -> Data? {
        let output = await GitProcessRunner.run([
            "--no-optional-locks", "-C", root, "show", "\(revision):\(path)"
        ])
        guard output.exitCode == 0, !output.standardOutput.isEmpty else { return nil }

        return output.standardOutput
    }

    private static func rejected(
        _ url: URL,
        content: FilePreview.Content,
        size: Int64 = 0
    ) -> FilePreview {
        FilePreview(
            url: url,
            content: content,
            size: size,
            kind: "Файл",
            modified: nil,
            isTruncated: false
        )
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

    private static func read(_ url: URL, text: String, rendering: Rendering) -> FilePreview {
        let size = Int64(text.utf8.count)
        let all = text.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline)
        let cut = all.count > Limit.lines
        let text = cut ? all.prefix(Limit.lines).joined(separator: "\n") : text

        if rendering == .rich, markdownExtensions.contains(url.pathExtension.lowercased()) {
            let blocks = MarkdownParser.blocks(from: text, baseURL: url.deletingLastPathComponent())

            return FilePreview(
                url: url,
                content: .markdown(blocks),
                size: size,
                kind: "Файл",
                modified: nil,
                isTruncated: cut
            )
        }

        return FilePreview(
            url: url,
            content: .code(CodeHighlighter.lines(text, language: url.pathExtension.lowercased())),
            size: size,
            kind: "Файл",
            modified: nil,
            isTruncated: cut
        )
    }

    private static func read(_ url: URL, rendering: Rendering) -> FilePreview {
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

        if
            imageExtensions.contains(url.pathExtension.lowercased()),
            values?.isRegularFile == true,
            size <= Limit.image,
            let data = try? Data(contentsOf: url, options: .mappedIfSafe) {
            return preview(.image(ImagePreview(new: data, old: nil)), truncated: false)
        }

        switch source(of: url, isRegular: values?.isRegularFile == true) {
        case let .rejected(content):
            return preview(content, truncated: false)

        case let .text(text):
            let lines = text.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline)
            let truncated = lines.count > Limit.lines
            let shown = truncated ? lines.prefix(Limit.lines).joined(separator: "\n") : text

            if rendering == .rich, markdownExtensions.contains(url.pathExtension.lowercased()) {
                let baseURL = url.deletingLastPathComponent()
                // Почему: разметка тоже режется, иначе мегабайтный файл раскладывается целиком
                let blocks = MarkdownParser.blocks(from: shown, baseURL: baseURL)

                return preview(.markdown(blocks), truncated: truncated)
            }

            return preview(
                .code(CodeHighlighter.lines(shown, language: url.pathExtension.lowercased())),
                truncated: truncated
            )
        }
    }
}
