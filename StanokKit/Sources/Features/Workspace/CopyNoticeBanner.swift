import SwiftUI

struct CopyNoticeBanner: View {

    var body: some View {
        Label("Терминал занят — команда скопирована", systemImage: "doc.on.clipboard")
            .font(.system(size: 12, weight: .medium))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.regularMaterial, in: .rect(cornerRadius: 10, style: .continuous))
            .shadow(radius: 6)
    }
}
