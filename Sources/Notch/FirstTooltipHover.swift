import Foundation

/// Only the first card after unfolding requires deliberate, continuous hovering.
struct FirstTooltipHover {
    private var needsDelay = false
    private var candidate: Int?
    private var enteredAt: TimeInterval = 0

    mutating func unfolded() {
        needsDelay = true
        candidate = nil
    }

    mutating func target(_ target: Int?, pinned: Bool, now: TimeInterval) -> Int? {
        if pinned { needsDelay = false }
        guard needsDelay else { return target }
        guard let target else { candidate = nil; return nil }
        if candidate != target {
            candidate = target
            enteredAt = now
        }
        guard now - enteredAt >= 2 else { return nil }
        needsDelay = false
        return target
    }
}
