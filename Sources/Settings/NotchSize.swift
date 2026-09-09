import Foundation

/// How large the notch is drawn.
///
/// A fixed set rather than a free number, for the same reason `PeekDuration` is
/// one: the useful range is narrow. Below about three quarters the percentage
/// under each ring stops being readable at a glance, which is the one thing the
/// notch exists to do; much above a quarter larger and a stack of five
/// providers is competing with the windows it sits beside rather than reporting
/// on them.
///
/// The scale multiplies the whole surface — rings, text, tooltip and all — so
/// the proportions stay exactly as they were drawn. `NotchLayout` keeps every
/// constant it quotes from the design frame, and `medium` is that frame at 1:1.
enum NotchSize: String, CaseIterable, Identifiable {
    case forty, fifty, fiftyFive, sixty, sixtyFive, seventy, seventyFive, ninety
    case small
    case medium
    case large

    var id: String { rawValue }

    /// What every measured distance is multiplied by. `medium` is 1, so it is
    /// the design frame untouched and the behaviour every earlier version had.
    var scale: CGFloat {
        switch self {
        case .forty: return 0.4
        case .fifty: return 0.5
        case .fiftyFive: return 0.55
        case .sixty: return 0.6
        case .sixtyFive: return 0.65
        case .seventy: return 0.7
        case .seventyFive: return 0.75
        case .ninety: return 0.9
        case .small:  return 0.8
        case .medium: return 1
        case .large:  return 1.25
        }
    }

    static var presets: [NotchSize] {
        allCases.filter { $0.scale <= 1 }.sorted { $0.scale < $1.scale }
    }
    var title: String { "\(Int((scale * 100).rounded()))%" }
    var explanation: String { "按所选比例缩放面板，100% 为原尺寸。" }
}
