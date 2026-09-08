import XCTest
@testable import Codenotch

final class FirstTooltipHoverTests: XCTestCase {
    func testFirstDwellAndSubsequentHover() {
        var hover = FirstTooltipHover()
        hover.unfolded()
        XCTAssertNil(hover.target(0, pinned: false, now: 10))
        XCTAssertNil(hover.target(0, pinned: false, now: 11.9))
        XCTAssertEqual(hover.target(0, pinned: false, now: 12), 0)
        XCTAssertEqual(hover.target(1, pinned: false, now: 12.1), 1)
        hover.unfolded()
        XCTAssertNil(hover.target(1, pinned: false, now: 20))
    }

    func testLeavingOrChangingTargetRestartsDwell() {
        var hover = FirstTooltipHover()
        hover.unfolded()
        XCTAssertNil(hover.target(0, pinned: false, now: 0))
        XCTAssertNil(hover.target(nil, pinned: false, now: 1))
        XCTAssertNil(hover.target(0, pinned: false, now: 2))
        XCTAssertNil(hover.target(1, pinned: false, now: 3))
        XCTAssertNil(hover.target(1, pinned: false, now: 4))
        XCTAssertEqual(hover.target(1, pinned: false, now: 5), 1)
    }

    func testPinnedAndOrdinaryOpenKeepImmediateBehaviour() {
        var hover = FirstTooltipHover()
        XCTAssertEqual(hover.target(0, pinned: false, now: 0), 0)
        hover.unfolded()
        XCTAssertNil(hover.target(0, pinned: false, now: 1))
        XCTAssertEqual(hover.target(0, pinned: true, now: 1.1), 0)
        XCTAssertEqual(hover.target(1, pinned: true, now: 1.2), 1)
    }
}

@MainActor
final class UsageDisplayModeTests: XCTestCase {
    private func snapshot(_ windows: [LimitWindow]) -> ProviderSnapshot {
        ProviderSnapshot(id: "codex", displayName: "Codex", glyph: .openai,
                         fidelity: .official, status: .ok, windows: windows)
    }

    func testUsedRemainingAndMissingDenominator() {
        let reading = snapshot([LimitWindow(id: "weekly", label: "Week", usedFraction: 0.2)])
        XCTAssertEqual(UsageDisplayMode.used.text(for: reading), "20%")
        XCTAssertEqual(UsageDisplayMode.remaining.text(for: reading), "80%")
        XCTAssertEqual(UsageDisplayMode.remaining.text(for: snapshot([])), "—")
        let count = snapshot([LimitWindow(id: "credits", label: "Credits", remaining: 12)])
        XCTAssertEqual(UsageDisplayMode.remaining.text(for: count), "12")
        let exhausted = snapshot([LimitWindow(id: "weekly", label: "Week", usedFraction: 1.2)])
        XCTAssertEqual(UsageDisplayMode.remaining.text(for: exhausted), "0%")
        XCTAssertEqual(UsageDisplayMode.used.text(for: exhausted), "120%")
    }

    func testPreferenceSurvivesRestart() {
        let defaults = UserDefaults(suiteName: "UsageDisplayModeTests.\(UUID().uuidString)")!
        let preferences = Preferences(defaults: defaults)
        XCTAssertEqual(preferences.usageDisplayMode, .used)
        preferences.usageDisplayMode = .remaining
        XCTAssertEqual(Preferences(defaults: defaults).usageDisplayMode, .remaining)
    }
}
