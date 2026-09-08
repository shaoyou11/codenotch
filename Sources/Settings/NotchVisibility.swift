import Foundation

/// How much of itself the notch shows when you are not using it.
///
/// Three states rather than the two that get asked for, because the default is
/// neither: at rest the notch is already a small pill that opens on contact.
/// Offering only "always" and "hidden" would quietly delete the behaviour the
/// app was designed around.
enum NotchVisibility: String, CaseIterable, Identifiable {
    /// Pinned open. The readings are always on screen.
    case alwaysShow
    /// A pill at the edge that unfolds when the pointer reaches it. The default.
    case onHover
    /// Nothing on screen at all.
    case hidden

    var id: String { rawValue }

    var title: String {
        switch self {
        case .alwaysShow: return "始终显示"
        case .onHover:    return "悬停展开"
        case .hidden:     return "隐藏"
        }
    }

    var explanation: String {
        switch self {
        case .alwaysShow:
            return "始终展开面板，显示全部用量。"
        case .onHover:
            return "平时显示小胶囊，鼠标移入后展开。"
        case .hidden:
            // Said here because a hidden notch is also a hidden way back in.
            // Names the menu bar route: with the notch off screen the readings
            // live in the menu bar menu instead, so Hide plus App icon "Menu
            // bar" is a working setup rather than a one-way door.
            return "隐藏悬浮面板。若选择菜单栏图标，仍可在菜单栏查看用量；也可从「应用程序」重新打开 CodenotchT 进入设置。"
        }
    }
}
