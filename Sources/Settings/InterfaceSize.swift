import Foundation

enum InterfaceSize: Int, CaseIterable, Identifiable {
    case tiny = 40, small = 50, smallPlus = 55, compact = 60, compactPlus = 65, standard = 70, medium = 75
    case comfortable = 80, large = 90, original = 100
    var id: Int { rawValue }
    var title: String { "\(rawValue)%" + (self == .original ? "（原尺寸）" : "") }
    var scale: CGFloat { CGFloat(rawValue) / 100 }
}
