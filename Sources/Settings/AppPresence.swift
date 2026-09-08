import AppKit

/// Where Codenotch shows itself, apart from the notch.
///
/// The notch is the product; this is only about how the *app* is reached — to
/// open settings, or to quit it. Three states because the two obvious ones
/// leave a gap: a Dock tile is easy to find and permanent, a menu bar item is
/// out of the way but still there, and some people want neither.
enum AppPresence: String, CaseIterable, Identifiable {
    /// A normal app: Dock tile, ⌘-Tab entry, menu bar of its own.
    case dock
    /// An icon in the menu bar, and nothing in the Dock.
    case menuBar
    /// Neither. Only the notch itself.
    case hidden

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dock:    return "程序坞"
        case .menuBar: return "菜单栏"
        case .hidden:  return "不显示"
        }
    }

    var explanation: String {
        switch self {
        case .dock:
            return "运行时在程序坞显示 CodenotchT 图标。"
        case .menuBar:
            return "仅在菜单栏显示图标，程序坞不显示。"
        case .hidden:
            // Said here because choosing this removes every visible way back to
            // these settings, and finding that out afterwards is too late.
            return "不显示应用图标，可从「应用程序」重新打开 CodenotchT 进入设置。"
        }
    }

    /// `.regular` is the only one that gets a Dock tile. Both others are
    /// accessory apps; what separates them is whether a status item is made.
    var activationPolicy: NSApplication.ActivationPolicy {
        self == .dock ? .regular : .accessory
    }

    var wantsStatusItem: Bool { self == .menuBar }
}
