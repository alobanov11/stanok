import Foundation
import os

public enum Log {

    public static let terminal = Logger(subsystem: subsystem, category: "terminal")

    private static let subsystem = Bundle.main.bundleIdentifier ?? "ru.alobanov11.Stanok"
}
