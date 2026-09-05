import SwiftUI

struct PreviewNoteSender: Sendable {

    let send: @MainActor @Sendable (PreviewNote) -> Void
}

extension EnvironmentValues {

    @Entry
    var previewNotes = PreviewNoteSender(send: { _ in })
}
