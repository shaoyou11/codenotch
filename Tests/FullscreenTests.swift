import AppKit
import XCTest
@testable import Codenotch

@MainActor
final class FullscreenTests: XCTestCase {
    func testFullscreenGeometryAndOrdinaryMaximizedWindow() {
        let screen = CGRect(x: 1440, y: 0, width: 1920, height: 1080)
        XCTAssertTrue(CustomFullscreenDetector.fillsScreen(screen, screen: screen))
        XCTAssertFalse(CustomFullscreenDetector.fillsScreen(CGRect(x: 1440, y: 25, width: 1920, height: 1055), screen: screen))
        XCTAssertFalse(CustomFullscreenDetector.fillsScreen(CGRect(x: 0, y: 0, width: 1920, height: 1080), screen: screen))
    }

    func testFullscreenOverridesPinAndRestoresIt() throws {
        guard !NSScreen.screens.isEmpty else { throw XCTSkip("No display") }
        let controller = NotchWindowController()
        controller.fullscreenCheck = { _ in false }
        controller.show()
        defer { controller.stop() }
        controller.model.isPinned = true
        controller.model.isExpanded = true
        controller.fullscreenCheck = { _ in true }
        controller.hideInFullscreen = true
        XCTAssertFalse(controller.panelVisibleForTesting)
        controller.peek(for: 5, focusing: nil)
        XCTAssertFalse(controller.panelVisibleForTesting)
        XCTAssertTrue(controller.model.isPinned)
        controller.fullscreenCheck = { _ in false }
        controller.hideInFullscreen = true
        XCTAssertFalse(controller.fullscreenSuppressedForTesting)
        XCTAssertFalse(controller.panelVisibleForTesting)
        XCTAssertTrue(controller.model.isPinned)
        XCTAssertTrue(controller.model.isExpanded)
        controller.fullscreenCheck = { _ in true }
        controller.hideInFullscreen = false
        XCTAssertFalse(controller.fullscreenSuppressedForTesting)
        XCTAssertFalse(controller.panelVisibleForTesting)
    }

    func testFullscreenPreferencePersists() {
        let defaults = UserDefaults(suiteName: "FullscreenTests.\(UUID().uuidString)")!
        let preferences = Preferences(defaults: defaults)
        XCTAssertTrue(preferences.hideInFullscreen)
        preferences.hideInFullscreen = false
        XCTAssertFalse(Preferences(defaults: defaults).hideInFullscreen)
    }
}
