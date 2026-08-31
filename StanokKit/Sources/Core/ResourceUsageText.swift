import Foundation

public enum ResourceUsageText {

    public static func text(for usage: ProcessTreeUsage?) -> String {
        guard let usage else { return "—" }

        return memory(usage.memoryBytes)
    }

    private static func memory(_ bytes: UInt64) -> String {
        let megabytes = Double(bytes) / 1_048_576
        guard megabytes >= 1024 else { return "\(Int(megabytes.rounded())) МБ" }

        return String(format: "%.1f ГБ", megabytes / 1024)
    }
}
