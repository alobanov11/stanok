import CoreGraphics

enum WorkspaceLayout {

    static let liveSessionLimit = 24
    static let inset: CGFloat = 12
    static let cardRadius: CGFloat = 16
    static let cardStyle = CardStyle.inset
    static let sidebarWidth: CGFloat = 360
    static let sidebarTopInset: CGFloat = 68
    static let minimumSplitWidth: CGFloat = 1000
    static let minimumPreviewWidth: CGFloat = 420
    static let filesWidth: CGFloat = 300
    static let toggleDuration = 0.28
    static let toggleWidth: CGFloat = 36
    static let toggleHeight: CGFloat = 28
    static let toggleGap: CGFloat = 10
    static let toggleClearance: CGFloat = 40
    static let headerHeight: CGFloat = 48
    static let unfocusedPaneOpacity: CGFloat = 0.7
    static let directorySettleDelay = Duration.milliseconds(150)
}
