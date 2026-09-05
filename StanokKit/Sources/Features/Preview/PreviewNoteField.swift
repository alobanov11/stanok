import SwiftUI

struct PreviewNoteField: View {

    var body: some View {
        HStack(spacing: 8) {
            Text("\(line)")
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundStyle(.tertiary)

            TextField("Правка к строке — Enter отправит в терминал", text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .focused($isFocused)
                .onSubmit(submit)

            Button(action: submit) {
                Image(systemName: "arrow.turn.down.left")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(text.isEmpty ? AnyShapeStyle(.tertiary) : AnyShapeStyle(.primary))
            }
            .buttonStyle(.plain)
            .disabled(text.isEmpty)

            Button(action: cancel) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.escape, modifiers: [])
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(.black.opacity(0.55), in: .rect(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(.white.opacity(0.14), lineWidth: 1)
        }
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

    private func cancel() {
        onCancel()
    }
}
