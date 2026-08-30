import SwiftUI

struct FileInfoView: View {

    private var reason: String {
        switch preview.content {
        case .tooLarge: "Файл слишком большой для просмотра"
        case let .failed(message): message
        default: "Это не текстовый файл — показать нечего"
        }
    }

    var body: some View {
        VStack(spacing: 14) {
            Spacer()

            Image(systemName: "doc")
                .font(.system(size: 34))
                .foregroundStyle(.tertiary)

            Text(reason)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 6) {
                field("Тип", preview.kind)
                field("Размер", preview.size.formatted(.byteCount(style: .file)))

                if let modified = preview.modified {
                    field("Изменён", modified.formatted(date: .abbreviated, time: .shortened))
                }
            }
            .padding(14)
            .background(.black.opacity(0.18), in: .rect(cornerRadius: 10, style: .continuous))

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24)
    }

    let preview: FilePreview

    private func field(_ name: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(name)
                .font(Typography.caption)
                .foregroundStyle(.tertiary)
                .frame(width: 64, alignment: .leading)

            Text(value)
                .font(Typography.caption)
                .textSelection(.enabled)

            Spacer(minLength: 0)
        }
    }
}
