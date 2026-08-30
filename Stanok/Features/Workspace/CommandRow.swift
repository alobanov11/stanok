import SwiftUI

struct CommandRow: View {

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(run.succeeded ? Color.green : Color.red)
                .frame(width: 6, height: 6)

            Text(run.exitCode.map { "exit \($0)" } ?? "прервана")
                .foregroundStyle(.primary)

            Spacer(minLength: 8)

            Text(run.duration.formatted(.units(allowed: [.seconds, .milliseconds], width: .narrow)))
                .foregroundStyle(.tertiary)
                .monospacedDigit()
        }
        .font(.system(size: 11))
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .contentShape(.rect(cornerRadius: 7))
    }

    let run: CommandRun

}
