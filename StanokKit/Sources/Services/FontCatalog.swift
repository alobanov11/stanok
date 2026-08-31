import AppKit

public enum FontCatalog {

    private static let preferredForReading = [
        "Charter", "Georgia", "PT Serif", "Palatino", "Iowan Old Style",
        "Baskerville", "Hoefler Text", "Times New Roman",
        "SF Pro Text", "Avenir Next", "Optima", "PT Sans",
        "Lucida Grande", "Helvetica Neue", "Verdana", "Tahoma", "Gill Sans"
    ]

    public static var monospaced: [String] {
        families { $0.isFixedPitch }
    }

    public static var reading: [String] {
        let proportional = families { !$0.isFixedPitch }
        let preferred = preferredForReading.filter(proportional.contains)
        let rest = proportional.filter { !preferred.contains($0) }

        return preferred + rest
    }

    private static func families(_ isIncluded: (NSFont) -> Bool) -> [String] {
        NSFontManager.shared.availableFontFamilies
            .filter { family in
                guard !family.hasPrefix("."), let font = NSFont(name: family, size: 12)
                else { return false }

                return isIncluded(font)
            }
            .sorted()
    }
}
