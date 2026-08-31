import AppKit

enum PreviewTypographyFonts {

    static func code(size: Double, family: String) -> NSFont {
        guard !family.isEmpty, let font = NSFont(name: family, size: size) else {
            return .monospacedSystemFont(ofSize: size, weight: .regular)
        }

        return font
    }

    static func reading(size: Double, family: String, weight: NSFont.Weight = .regular) -> NSFont {
        guard !family.isEmpty, let font = NSFont(name: family, size: size) else {
            return .systemFont(ofSize: size, weight: weight)
        }

        guard weight != .regular else { return font }

        let descriptor = font.fontDescriptor.withSymbolicTraits(.bold)
        return NSFont(descriptor: descriptor, size: size) ?? font
    }
}
