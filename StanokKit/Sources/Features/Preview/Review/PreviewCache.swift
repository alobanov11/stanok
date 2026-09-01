import Foundation

@MainActor
@Observable
final class PreviewCache {

    // Почему: повторное раскрытие карточки не должно снова читать файл и считать дифф
    private static let capacity = 6

    private var entries: [String: FilePreview] = [:]
    private var order: [String] = []

    func preview(for key: String) -> FilePreview? {
        guard let found = entries[key] else { return nil }

        touch(key)

        return found
    }

    func store(_ preview: FilePreview, for key: String) {
        entries[key] = preview
        touch(key)

        while order.count > Self.capacity, let oldest = order.first {
            order.removeFirst()
            entries[oldest] = nil
        }
    }

    private func touch(_ key: String) {
        order.removeAll { $0 == key }
        order.append(key)
    }
}
