import SwiftUI

struct PreviewNoteField: View {

    private enum Metric {

        static let radius: CGFloat = 10
        static let height: CGFloat = 32
    }

    var body: some View {
        HStack(spacing: 8) {
            Text("\(line)")
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundStyle(.tertiary)

            TextField("Правка — Enter отправит в терминал", text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .focused($isFocused)
                .onSubmit(submit)

            Button(action: submit) {
                Image(systemName: "arrow.turn.down.left")
                    .font(.system(size: 11, weight: .semibold))
            }
            .buttonStyle(.plain)
            .foregroundStyle(text.isEmpty ? AnyShapeStyle(.tertiary) : AnyShapeStyle(.primary))
            .disabled(text.isEmpty)

            Button(action: onCancel) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.escape, modifiers: [])
        }
        .padding(.horizontal, 10)
        .frame(height: Metric.height)
        .background(.regularMaterial, in: .rect(cornerRadius: Metric.radius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Metric.radius, style: .continuous)
                .strokeBorder(.white.opacity(0.12), lineWidth: 1)
        }
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 1, style: .continuous)
                .fill(Color.accentColor)
                .frame(width: 2, height: Metric.height - 12)
                .padding(.leading, 3)
        }
        .shadow(color: .black.opacity(0.35), radius: 12, y: 4)
        .task { isFocused = true }
    }

    let line: Int
    let onSend: (String) -> Void
    let onCancel: () -> Void

    @State
    private var text = ""

    @FocusState
    private var isFocused: Bool

    private func submit() {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        onSend(trimmed)
    }
}
