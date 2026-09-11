import XCTest
@testable import Codenotch

@MainActor
final class CustomChromeTests: XCTestCase {
    func testFixedControlsAppearOnlyWhenReachedFor() {
        let model = NotchViewModel()
        model.isExpanded = true
        model.isAlwaysOn = true
        XCTAssertFalse(model.showsChrome)
        model.isPointerOverSurface = true
        XCTAssertTrue(model.showsChrome)
        model.isPointerOverSurface = false
        XCTAssertFalse(model.showsChrome)
        model.isMoving = true
        XCTAssertTrue(model.showsChrome)
        model.isExpanded = false
        XCTAssertFalse(model.showsChrome)
    }

    func testHoverAndPinModesKeepTheirOwnBehavior() {
        let model = NotchViewModel()
        model.isExpanded = true
        XCTAssertTrue(model.showsChrome)
        model.isPinned = true
        XCTAssertFalse(model.showsChrome)
        model.isHoveringSettings = true
        XCTAssertTrue(model.showsChrome)
    }
}
