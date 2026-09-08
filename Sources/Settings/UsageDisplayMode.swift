import Foundation

enum UsageDisplayMode: String, CaseIterable, Identifiable {
    case used, remaining
    var id: String { rawValue }
    var title: String { self == .used ? "已用" : "剩余" }

    func text(for snapshot: ProviderSnapshot) -> String {
        guard snapshot.hasReading else { return "—" }
        guard let fraction = snapshot.usedFraction, fraction.isFinite else {
            return snapshot.headlineText
        }
        guard self == .remaining else { return snapshot.headlineText }
        return Percent.text(for: max(0, min(1, 1 - fraction))) + "%"
    }
}
