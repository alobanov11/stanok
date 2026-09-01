import SwiftUI

public struct TerminalSettings: View {

    private static let systemFamily = ""

    @State
    private var family: String = ConfigFile.value(for: "font-family") ?? ""

    @State
    private var size = Double(ConfigFile.value(for: "font-size") ?? "") ?? 15

    @State
    private var lineHeight = Double(
        (ConfigFile.value(for: "adjust-cell-height") ?? "").replacingOccurrences(of: "%", with: "")
    ) ?? 40

    public var body: some View {
        Form {
            Section("Шрифт") {
                Picker("Гарнитура", selection: $family) {
                    Text("Системный").tag(Self.systemFamily)

                    ForEach(families, id: \.self) { name in
                        Text(name).tag(name)
                    }
                }
                .onChange(of: family) { _, new in
                    if new.isEmpty {
                        ConfigFile.remove("font-family")
                    } else {
                        ConfigFile.set("font-family", to: new)
                    }
                }

                LabeledContent("Размер") {
                    HStack(spacing: 10) {
                        Slider(value: $size, in: 9...28, step: 1) { editing in
                            guard !editing else { return }

                            ConfigFile.set("font-size", to: "\(Int(size))")
                        }
                        .frame(width: 180)

                        Text("\(Int(size))")
                            .monospacedDigit()
                            .frame(width: 24, alignment: .trailing)
                    }
                }

                LabeledContent("Высота строки") {
                    HStack(spacing: 10) {
                        Slider(value: $lineHeight, in: 0...80, step: 5) { editing in
                            guard !editing else { return }

                            ConfigFile.set("adjust-cell-height", to: "\(Int(lineHeight))%")
                        }
                        .frame(width: 180)

                        Text("\(Int(lineHeight))%")
                            .monospacedDigit()
                            .frame(width: 36, alignment: .trailing)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .scrollDisabled(true)
    }

    private let families = FontCatalog.monospaced

    public init() {}
}
