import AppKit

public enum FontCatalog {

    public static var monospaced: [String] {
        NSFontManager.shared.availableFontFamilies
            .filter { family in
                guard !family.hasPrefix(".") else { return false }
                guard let font = NSFont(name: family, size: 12) else { return false }
                return font.isFixedPitch
            }
            .sorted()
    }
}
