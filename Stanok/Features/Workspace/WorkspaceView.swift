import SwiftUI

struct WorkspaceView: View {
    var body: some View {
        VStack(spacing: 8) {
            Text("stanok").font(.largeTitle.weight(.semibold))
            Text("libghostty \(GhosttyInfo.version) · \(GhosttyInfo.buildMode)")
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(.secondary)
        }
        .frame(minWidth: 420, minHeight: 240)
    }
}

#Preview {
    WorkspaceView()
}
