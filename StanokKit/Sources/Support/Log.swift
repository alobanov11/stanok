import Foundation
import os

public enum Log {

    public static let terminal = Logger(subsystem: subsystem, category: "terminal")
    public static let agents = Logger(subsystem: subsystem, category: "agents")

    private static let subsystem = Bundle.main.bundleIdentifier ?? "ru.alobanov11.Stanok"
}
