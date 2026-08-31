import Foundation

public enum ShellQuoting {

    private static let safe = CharacterSet(
        charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_./:=@,+"
    )

    public static func posixQuote(_ arguments: [String]) -> String {
        arguments.map(quote).joined(separator: " ")
    }

    private static func quote(_ argument: String) -> String {
        guard needsQuoting(argument) else { return argument }

        return "'" + argument.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    private static func needsQuoting(_ argument: String) -> Bool {
        guard !argument.isEmpty else { return true }

        return argument.unicodeScalars.contains { !safe.contains($0) }
    }
}
