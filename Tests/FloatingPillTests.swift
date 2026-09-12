import XCTest
import SwiftUI
@testable import Codenotch

@MainActor
final class FloatingPillTests: XCTestCase {
    func testFloatingPlacementAndInverseAgreeOnEveryEdge() {
        for edge in NotchEdge.allCases {
            let place = NotchPlacement(edge: edge, panelSize: CGSize(width: 400, height: 600), edgeInset: 6)
            let point = place.point(along: 100, across: 20)
            XCTAssertEqual(place.across(of: point), 20, accuracy: 0.001)
            XCTAssertEqual(place.along(of: point), 100, accuracy: 0.001)
            let rect = place.rect(along: 80, across: 0, length: 40, depth: 40)
            XCTAssertTrue(rect.contains(point))
            XCTAssertFalse(rect.contains(NotchPlacement(edge: edge, panelSize: place.panelSize).point(along: 100, across: 2)))
        }
    }

    func testPinnedAndAlwaysShownPanelsHaveAStableGapAtEveryScale() {
        let model = NotchViewModel()
        XCTAssertFalse(model.usesFloatingPill)
        model.isPinned = true
        for scale in [0.3, 0.65, 1.0] {
            model.sizeScale = scale
            XCTAssertTrue(model.usesFloatingPill)
            XCTAssertEqual(model.surfaceEdgeInset, 6)
        }
        model.isPinned = false
        model.isAlwaysOn = true
        XCTAssertEqual(model.surfaceEdgeInset, 6)
    }

    func testFloatingPillDropsOnlyFlarePaddingAndCentersItsControls() {
        let model = NotchViewModel()
        model.isExpanded = true
        let original = model.shapeLength
        model.isAlwaysOn = true
        XCTAssertEqual(model.flare, 0)
        XCTAssertEqual(model.shapeLength, original - 2 * NotchLayout.curlRadius, accuracy: 0.001)
        XCTAssertEqual(model.shapeLength, model.bodyLength, accuracy: 0.001)
        XCTAssertEqual(model.orbInset, NotchLayout.bodyDepth(for: model.edge) / 2)
        XCTAssertEqual(-model.moveAlong, model.orbAlong - model.shapeLength)
        XCTAssertTrue(model.isOnOrbHandle(along: model.orbAlong, across: model.orbInset))
        XCTAssertFalse(model.isOnOrbHandle(along: model.shapeLength - 1, across: model.orbInset))
        XCTAssertTrue(model.isOnMoveHandle(along: model.moveAlong, across: model.orbInset))
        XCTAssertFalse(model.isOnMoveHandle(along: 1, across: model.orbInset))
    }

    func testFloatingOutlineHasFourRoundedCornersAndNoFlares() {
        for edge in NotchEdge.allCases {
            let size = edge.isVertical ? CGSize(width: 50, height: 110) : CGSize(width: 110, height: 50)
            let rect = CGRect(origin: .zero, size: size)
            let path = SideNotchShape(edge: edge, capsuleDepth: 10, floating: 1).path(in: rect)
            XCTAssertTrue(path.contains(CGPoint(x: size.width / 2, y: size.height / 2)))
            for point in [CGPoint(x: 1, y: 1), CGPoint(x: size.width - 1, y: 1),
                          CGPoint(x: 1, y: size.height - 1), CGPoint(x: size.width - 1, y: size.height - 1)] {
                XCTAssertFalse(path.contains(point))
            }
            XCTAssertEqual(path.boundingRect, rect)
        }
    }
}
