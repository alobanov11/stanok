import SwiftUI

public struct TerminalSettings: View {

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
                    ForEach(families, id: \.self) { name in
                        Text(name).tag(name)
                    }
                }
                .onChange(of: family) { _, new in
                    ConfigFile.set("font-family", to: new)
                }

                LabeledContent("Размер") {
                    HStack(spacing: 10) {
                        Slider(value: $size, in: 9...28, step: 1)
                            .frame(width: 180)

                        Text("\(Int(size))")
                            .monospacedDigit()
                            .frame(width: 24, alignment: .trailing)
                    }
                }
                .onChange(of: size) { _, new in
                    ConfigFile.set("font-size", to: "\(Int(new))")
                }

                LabeledContent("Высота строки") {
                    HStack(spacing: 10) {
                        Slider(value: $lineHeight, in: 0...80, step: 5)
                            .frame(width: 180)

                        Text("\(Int(lineHeight))%")
                            .monospacedDigit()
                            .frame(width: 36, alignment: .trailing)
                    }
                }
                .onChange(of: lineHeight) { _, new in
                    ConfigFile.set("adjust-cell-height", to: "\(Int(new))%")
                }
            }
        }
        .formStyle(.grouped)
        .scrollDisabled(true)
    }

    private let families = FontCatalog.monospaced

    public init() {}
}
