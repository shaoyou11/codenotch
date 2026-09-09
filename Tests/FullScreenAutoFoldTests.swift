import AppKit
import Combine
import SwiftUI
import XCTest
@testable import Codenotch

@MainActor
final class FullScreenAutoFoldTests: XCTestCase {
    func testDetectorFindsFullScreenWindowMatchingScreenBounds() {
        let screen = CGRect(x: 0, y: 0, width: 1728, height: 1117)
        let pid: pid_t = 12345
        let windows: [(pid: pid_t, layer: Int, bounds: CGRect)] = [
            (pid: 9999, layer: 0, bounds: CGRect(x: 50, y: 50, width: 800, height: 600)),
            (pid: pid, layer: 0, bounds: screen),
            (pid: pid, layer: 24, bounds: screen) // menu bar or overlay
        ]

        XCTAssertTrue(FullScreenDetector.isFullScreen(screenBounds: screen, frontmostPID: pid, windows: windows))
    }

    func testDetectorRejectsWindowWhenNotMatchingScreenBounds() {
        let screen = CGRect(x: 0, y: 0, width: 1728, height: 1117)
        let pid: pid_t = 12345
        let windows: [(pid: pid_t, layer: Int, bounds: CGRect)] = [
            (pid: pid, layer: 0, bounds: CGRect(x: 100, y: 100, width: 1200, height: 800))
        ]

        XCTAssertFalse(FullScreenDetector.isFullScreen(screenBounds: screen, frontmostPID: pid, windows: windows))
    }

    func testDetectorRejectsFullScreenWindowOfNonFrontmostApp() {
        let screen = CGRect(x: 0, y: 0, width: 1728, height: 1117)
        let frontPID: pid_t = 12345
        let otherPID: pid_t = 67890
        let windows: [(pid: pid_t, layer: Int, bounds: CGRect)] = [
            (pid: otherPID, layer: 0, bounds: screen)
        ]

        XCTAssertFalse(FullScreenDetector.isFullScreen(screenBounds: screen, frontmostPID: frontPID, windows: windows))
    }

    func testControllerAutoFoldsWhenActiveSpaceChangesToFullScreen() {
        let controller = NotchWindowController()
        controller.show()
        defer { controller.stop() }

        controller.model.isExpanded = true
        controller.model.isPinned = true
        controller.fullscreenCheck = { _ in true }

        // Post active space changed notification
        NSWorkspace.shared.notificationCenter.post(
            name: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil
        )

        XCTAssertFalse(controller.panelVisibleForTesting)
        XCTAssertTrue(controller.model.isPinned)
    }

    func testControllerAutoFoldsWhenFullscreenAppActivates() {
        let controller = NotchWindowController()
        controller.show()
        defer { controller.stop() }

        controller.model.isExpanded = true
        controller.fullscreenCheck = { _ in true }

        // Post application activation notification
        NSWorkspace.shared.notificationCenter.post(
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )

        XCTAssertFalse(controller.panelVisibleForTesting)
    }

    func testControllerDoesNotFoldWhenAppIsNotFullScreen() {
        let controller = NotchWindowController()
        controller.show()
        defer { controller.stop() }

        controller.model.isExpanded = true
        controller.fullscreenCheck = { _ in false }

        NSWorkspace.shared.notificationCenter.post(
            name: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil
        )

        XCTAssertTrue(controller.model.isExpanded, "The notch should stay open if the active space is not full-screen")
    }

    func testAlwaysOnRestoresExpandedWhenLeavingFullScreen() {
        let controller = NotchWindowController()
        controller.show()
        defer { controller.stop() }

        controller.model.isAlwaysOn = true
        controller.model.isExpanded = true

        // Simulate entering full-screen
        controller.fullscreenCheck = { _ in true }
        controller.handleActiveSpaceOrAppChange()
        XCTAssertFalse(controller.panelVisibleForTesting)

        // Simulate returning to desktop
        controller.fullscreenCheck = { _ in false }
        controller.handleActiveSpaceOrAppChange()
        XCTAssertTrue(controller.model.isExpanded, "Always-on notch should unfold again when leaving full screen")
    }
}
