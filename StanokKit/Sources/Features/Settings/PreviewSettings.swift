import SwiftUI

public struct PreviewSettings: View {

    @AppStorage(PreviewTypography.Keys.markdownFontFamily)
    private var markdownFontFamily = PreviewTypography.Defaults.markdownFontFamily

    @AppStorage(PreviewTypography.Keys.markdownFontSize)
    private var markdownFontSize = PreviewTypography.Defaults.markdownFontSize

    @AppStorage(PreviewTypography.Keys.markdownLineSpacing)
    private var markdownLineSpacing = PreviewTypography.Defaults.markdownLineSpacing

    @AppStorage(PreviewTypography.Keys.codeFontSize)
    private var codeFontSize = PreviewTypography.Defaults.codeFontSize

    @AppStorage(PreviewTypography.Keys.codeFontFamily)
    private var codeFontFamily = PreviewTypography.Defaults.codeFontFamily

    public var body: some View {
        Form {
            Section("Markdown") {
                Picker("Гарнитура", selection: $markdownFontFamily) {
                    Text("Системный").tag("")
                    ForEach(readingFamilies, id: \.self) { name in
                        Text(name).tag(name)
                    }
                }

                LabeledContent("Размер текста") {
                    HStack(spacing: 10) {
                        Slider(
                            value: $markdownFontSize,
                            in: PreviewTypography.Ranges.markdownFontSize,
                            step: 1
                        )
                        .frame(width: 180)

                        Text("\(Int(markdownFontSize))")
                            .monospacedDigit()
                            .frame(width: 24, alignment: .trailing)
                    }
                }

                LabeledContent("Межстрочный интервал") {
                    HStack(spacing: 10) {
                        Slider(
                            value: $markdownLineSpacing,
                            in: PreviewTypography.Ranges.markdownLineSpacing,
                            step: 1
                        )
                        .frame(width: 180)

                        Text("\(Int(markdownLineSpacing))")
                            .monospacedDigit()
                            .frame(width: 24, alignment: .trailing)
                    }
                }
            }

            Section("Код") {
                Picker("Гарнитура", selection: $codeFontFamily) {
                    Text("Системный").tag("")
                    ForEach(families, id: \.self) { name in
                        Text(name).tag(name)
                    }
                }

                LabeledContent("Размер") {
                    HStack(spacing: 10) {
                        Slider(
                            value: $codeFontSize,
                            in: PreviewTypography.Ranges.codeFontSize,
                            step: 1
                        )
                        .frame(width: 180)

                        Text("\(Int(codeFontSize))")
                            .monospacedDigit()
                            .frame(width: 24, alignment: .trailing)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .scrollDisabled(true)
    }

    private let families = FontCatalog.monospaced

    private let readingFamilies = FontCatalog.reading

    public init() {}

}
