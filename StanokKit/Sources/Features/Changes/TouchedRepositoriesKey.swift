import SwiftUI

private struct TouchedRepositoriesKey: EnvironmentKey {

    static let defaultValue: TouchedRepositoriesModel? = nil
}

public extension EnvironmentValues {

    var touchedRepositories: TouchedRepositoriesModel? {
        get { self[TouchedRepositoriesKey.self] }
        set { self[TouchedRepositoriesKey.self] = newValue }
    }
}
