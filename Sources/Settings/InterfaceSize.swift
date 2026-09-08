import Foundation

enum InterfaceSize: Int, CaseIterable, Identifiable {
    case small = 50, compact = 60, standard = 70, medium = 75
    case comfortable = 80, large = 90, original = 100, extraLarge = 125
    var id: Int { rawValue }
    var title: String { "\(rawValue)%" + (self == .original ? "（原尺寸）" : "") }
    var scale: CGFloat { CGFloat(rawValue) / 100 }
}
