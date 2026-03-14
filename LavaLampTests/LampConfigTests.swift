import XCTest
@testable import LavaLamp

final class LampConfigTests: XCTestCase {

    // MARK: - Constants

    func testGridDimensions() {
        XCTAssertEqual(LampConfig.gridWidth, 48)
        XCTAssertEqual(LampConfig.gridHeight, 120)
    }

    func testGlassTopAboveGlassBottom() {
        XCTAssertLessThan(LampConfig.glassTop, LampConfig.glassBottom)
    }

    func testCapAboveGlass() {
        XCTAssertLessThanOrEqual(LampConfig.capBottom, LampConfig.glassTop)
    }

    func testBaseAttachedToGlassBottom() {
        XCTAssertGreaterThanOrEqual(LampConfig.baseTop, LampConfig.glassBottom)
    }

    func testCapTopAboveCapBottom() {
        XCTAssertLessThan(LampConfig.capTop, LampConfig.capBottom)
    }

    func testBaseTopAboveBaseBottom() {
        XCTAssertLessThan(LampConfig.baseTop, LampConfig.baseBottom)
    }

    func testAllPartsWithinGrid() {
        XCTAssertGreaterThanOrEqual(LampConfig.capTop, 0)
        XCTAssertLessThanOrEqual(LampConfig.baseBottom, LampConfig.gridHeight)
    }

    func testGlassMaxHalfWidthPositive() {
        XCTAssertGreaterThan(LampConfig.glassMaxHalfWidth, 0)
    }

    func testGlassMaxHalfWidthLessThanHalfGrid() {
        XCTAssertLessThan(LampConfig.glassMaxHalfWidth, CGFloat(LampConfig.gridWidth) / 2)
    }

    // MARK: - Glass Half-Width Shape

    func testGlassWidestAtCenter() {
        let center = CGFloat(LampConfig.glassTop + LampConfig.glassBottom) / 2
        let widthAtCenter = LampConfig.glassHalfWidth(atRow: center)
        let widthAtTop = LampConfig.glassHalfWidth(atRow: CGFloat(LampConfig.glassTop))
        let widthAtBottom = LampConfig.glassHalfWidth(atRow: CGFloat(LampConfig.glassBottom))

        XCTAssertGreaterThanOrEqual(widthAtCenter, widthAtTop,
            "Glass should be widest at center")
        XCTAssertGreaterThanOrEqual(widthAtCenter, widthAtBottom,
            "Glass should be widest at center")
    }

    func testGlassSymmetricAboutCenter() {
        let center = CGFloat(LampConfig.glassTop + LampConfig.glassBottom) / 2
        let offset: CGFloat = 20

        let widthAbove = LampConfig.glassHalfWidth(atRow: center - offset)
        let widthBelow = LampConfig.glassHalfWidth(atRow: center + offset)

        XCTAssertEqual(widthAbove, widthBelow, accuracy: 0.001,
            "Glass should be symmetric about center")
    }

    func testGlassHalfWidthAlwaysPositive() {
        for y in LampConfig.glassTop...LampConfig.glassBottom {
            let hw = LampConfig.glassHalfWidth(atRow: CGFloat(y))
            XCTAssertGreaterThan(hw, 0, "Glass half-width should be positive at row \(y)")
        }
    }

    func testGlassHalfWidthNeverExceedsMax() {
        for y in LampConfig.glassTop...LampConfig.glassBottom {
            let hw = LampConfig.glassHalfWidth(atRow: CGFloat(y))
            XCTAssertLessThanOrEqual(hw, LampConfig.glassMaxHalfWidth + 0.001,
                "Glass half-width should not exceed max at row \(y)")
        }
    }

    func testGlassTapersNearEdges() {
        let center = CGFloat(LampConfig.glassTop + LampConfig.glassBottom) / 2
        let widthAtCenter = LampConfig.glassHalfWidth(atRow: center)
        let widthNearTop = LampConfig.glassHalfWidth(atRow: CGFloat(LampConfig.glassTop + 2))

        XCTAssertGreaterThan(widthAtCenter, widthNearTop,
            "Glass should taper near edges")
    }

    func testGlassHalfWidthAtExactCenter() {
        let center = CGFloat(LampConfig.glassTop + LampConfig.glassBottom) / 2
        let hw = LampConfig.glassHalfWidth(atRow: center)
        // At center, normalizedDist = 0, taper = 1.0, so hw = glassMaxHalfWidth
        XCTAssertEqual(hw, LampConfig.glassMaxHalfWidth, accuracy: 0.001)
    }
}
