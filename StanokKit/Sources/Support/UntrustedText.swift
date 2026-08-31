import Foundation

public enum UntrustedText {

    public static func sanitizedSingleLine(_ raw: String, maxLength: Int) -> String {
        let filtered = raw.unicodeScalars.filter { scalar in
            !CharacterSet.controlCharacters.contains(scalar)
                && !CharacterSet.newlines.contains(scalar)
        }
        let cleaned = String(String.UnicodeScalarView(filtered))
            .trimmingCharacters(in: .whitespaces)
        guard cleaned.count > maxLength, maxLength > 0 else { return cleaned }

        return String(cleaned.prefix(maxLength)) + "…"
    }
}
