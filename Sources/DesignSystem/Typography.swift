import SwiftUI

/// Sizes are derived from cap heights measured in the design frame, so they
/// track `Design.scale` along with everything else.
enum Typography {
    /// The percent under each provider ring. Cap height 27px in the frame.
    static var percent: Font { Font.system(size: Design.fontSize(capPixels: 27), weight: .semibold) }

    /// "Claude Usage". Cap height 26px.
    static var cardTitle: Font { Font.system(size: max(12 * Design.interfaceScale / 0.70, Design.fontSize(capPixels: 26)), weight: .semibold) }

    /// "Current session", "73% Used", "Resets in 51 min". Cap height 18px.
    static var cardBody: Font { Font.system(size: max(11 * Design.interfaceScale / 0.70, Design.fontSize(capPixels: 18)), weight: .regular) }
}
