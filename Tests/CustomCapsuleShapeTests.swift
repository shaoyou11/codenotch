import XCTest
import SwiftUI
@testable import Codenotch

final class CustomCapsuleShapeTests: XCTestCase {
    func testRestingCapsuleHasRoundedBezelCornersOnEveryEdge() {
        for edge in NotchEdge.allCases {
            let size = edge.isVertical ? CGSize(width: 10, height: 40) : CGSize(width: 40, height: 10)
            let path = SideNotchShape(edge: edge, capsuleDepth: 10).path(in: CGRect(origin: .zero, size: size))
            XCTAssertTrue(path.contains(CGPoint(x: size.width / 2, y: size.height / 2)))
            XCTAssertFalse(path.contains(CGPoint(x: 0.1, y: 0.1)))
            XCTAssertEqual(path.boundingRect.width, size.width, accuracy: 0.001)
            XCTAssertEqual(path.boundingRect.height, size.height, accuracy: 0.001)
        }
    }

    func testIntermediateOutlinesStayInsideTheirPresentedFrame() {
        let shape = SideNotchShape(edge: .right, capsuleDepth: 10)
        for depth in stride(from: 10.0, through: 60.0, by: 0.5) {
            let rect = CGRect(x: 0, y: 0, width: depth, height: depth * 4)
            let bounds = shape.path(in: rect).boundingRect
            XCTAssertGreaterThanOrEqual(bounds.minX, -0.001)
            XCTAssertLessThanOrEqual(bounds.maxX, rect.maxX + 0.001)
            XCTAssertGreaterThanOrEqual(bounds.minY, -0.001)
            XCTAssertLessThanOrEqual(bounds.maxY, rect.maxY + 0.001)
        }
    }
}
