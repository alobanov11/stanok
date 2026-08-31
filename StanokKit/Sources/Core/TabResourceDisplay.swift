import Foundation

public enum TabResourceDisplay {

    public static let cpuThresholdPercent = 3.0

    public static func text(for usage: ProcessTreeUsage?) -> String? {
        guard let usage, let cpuPercent = usage.cpuPercent, cpuPercent >= cpuThresholdPercent
        else { return nil }

        return "\(Int(cpuPercent.rounded()))% · \(formattedMemory(usage.memoryBytes))"
    }

    private static func formattedMemory(_ bytes: UInt64) -> String {
        let megabytes = Double(bytes) / 1_048_576
        guard megabytes >= 1024 else { return "\(Int(megabytes.rounded())) МБ" }

        return String(format: "%.1f ГБ", megabytes / 1024)
    }
}
