import XCTest
@testable import LavaLamp

final class LavaLampUtilsTests: XCTestCase {

    // MARK: - colorFromHex

    func testColorFromHexBasic() {
        let color = LavaLampUtils.colorFromHex("FF6600")
        XCTAssertNotNil(color)
        let c = color!.usingColorSpace(.sRGB)!
        XCTAssertEqual(c.redComponent, 1.0, accuracy: 0.01)
        XCTAssertEqual(c.greenComponent, 0.4, accuracy: 0.01)
        XCTAssertEqual(c.blueComponent, 0.0, accuracy: 0.01)
    }

    func testColorFromHexWithHash() {
        let color = LavaLampUtils.colorFromHex("#FF6600")
        XCTAssertNotNil(color)
        let c = color!.usingColorSpace(.sRGB)!
        XCTAssertEqual(c.redComponent, 1.0, accuracy: 0.01)
    }

    func testColorFromHexBlack() {
        let color = LavaLampUtils.colorFromHex("000000")
        XCTAssertNotNil(color)
        let c = color!.usingColorSpace(.sRGB)!
        XCTAssertEqual(c.redComponent, 0.0, accuracy: 0.01)
        XCTAssertEqual(c.greenComponent, 0.0, accuracy: 0.01)
        XCTAssertEqual(c.blueComponent, 0.0, accuracy: 0.01)
    }

    func testColorFromHexWhite() {
        let color = LavaLampUtils.colorFromHex("FFFFFF")
        XCTAssertNotNil(color)
        let c = color!.usingColorSpace(.sRGB)!
        XCTAssertEqual(c.redComponent, 1.0, accuracy: 0.01)
        XCTAssertEqual(c.greenComponent, 1.0, accuracy: 0.01)
        XCTAssertEqual(c.blueComponent, 1.0, accuracy: 0.01)
    }

    func testColorFromHexLowercase() {
        let color = LavaLampUtils.colorFromHex("ff6600")
        XCTAssertNotNil(color)
        let c = color!.usingColorSpace(.sRGB)!
        XCTAssertEqual(c.redComponent, 1.0, accuracy: 0.01)
    }

    func testColorFromHexMixedCase() {
        let color = LavaLampUtils.colorFromHex("Ff6600")
        XCTAssertNotNil(color)
    }

    func testColorFromHexWithWhitespace() {
        let color = LavaLampUtils.colorFromHex("  FF6600  ")
        XCTAssertNotNil(color)
    }

    func testColorFromHexWithHashAndWhitespace() {
        let color = LavaLampUtils.colorFromHex("  #FF6600  ")
        XCTAssertNotNil(color)
    }

    func testColorFromHexInvalidTooShort() {
        XCTAssertNil(LavaLampUtils.colorFromHex("FF66"))
    }

    func testColorFromHexInvalidTooLong() {
        XCTAssertNil(LavaLampUtils.colorFromHex("FF660000"))
    }

    func testColorFromHexInvalidCharacters() {
        XCTAssertNil(LavaLampUtils.colorFromHex("GGHHII"))
    }

    func testColorFromHexEmptyString() {
        XCTAssertNil(LavaLampUtils.colorFromHex(""))
    }

    func testColorFromHexHashOnly() {
        XCTAssertNil(LavaLampUtils.colorFromHex("#"))
    }

    func testColorFromHexSpecificComponents() {
        let color = LavaLampUtils.colorFromHex("1E88E5")!.usingColorSpace(.sRGB)!
        XCTAssertEqual(color.redComponent, CGFloat(0x1E) / 255.0, accuracy: 0.001)
        XCTAssertEqual(color.greenComponent, CGFloat(0x88) / 255.0, accuracy: 0.001)
        XCTAssertEqual(color.blueComponent, CGFloat(0xE5) / 255.0, accuracy: 0.001)
    }

    // MARK: - parseColor

    func testParseColorFromHexParam() {
        let params = [URLQueryItem(name: "hex", value: "FF6600")]
        let color = LavaLampUtils.parseColor(from: params)
        XCTAssertNotNil(color)
    }

    func testParseColorFromRGBParams() {
        let params = [
            URLQueryItem(name: "r", value: "0.2"),
            URLQueryItem(name: "g", value: "0.4"),
            URLQueryItem(name: "b", value: "1.0"),
        ]
        let color = LavaLampUtils.parseColor(from: params)
        XCTAssertNotNil(color)
        let c = color!.usingColorSpace(.sRGB)!
        XCTAssertEqual(c.redComponent, 0.2, accuracy: 0.01)
        XCTAssertEqual(c.greenComponent, 0.4, accuracy: 0.01)
        XCTAssertEqual(c.blueComponent, 1.0, accuracy: 0.01)
    }

    func testParseColorHexTakesPrecedence() {
        let params = [
            URLQueryItem(name: "hex", value: "FF0000"),
            URLQueryItem(name: "r", value: "0.0"),
            URLQueryItem(name: "g", value: "1.0"),
            URLQueryItem(name: "b", value: "0.0"),
        ]
        let color = LavaLampUtils.parseColor(from: params)!.usingColorSpace(.sRGB)!
        // hex=FF0000 -> red=1.0, not the RGB params
        XCTAssertEqual(color.redComponent, 1.0, accuracy: 0.01)
        XCTAssertEqual(color.greenComponent, 0.0, accuracy: 0.01)
    }

    func testParseColorMissingParams() {
        let params = [URLQueryItem(name: "unrelated", value: "value")]
        XCTAssertNil(LavaLampUtils.parseColor(from: params))
    }

    func testParseColorEmptyParams() {
        XCTAssertNil(LavaLampUtils.parseColor(from: []))
    }

    func testParseColorPartialRGBMissing() {
        let params = [
            URLQueryItem(name: "r", value: "0.5"),
            URLQueryItem(name: "g", value: "0.5"),
            // missing b
        ]
        XCTAssertNil(LavaLampUtils.parseColor(from: params))
    }

    func testParseColorInvalidRGBValues() {
        let params = [
            URLQueryItem(name: "r", value: "not_a_number"),
            URLQueryItem(name: "g", value: "0.5"),
            URLQueryItem(name: "b", value: "0.5"),
        ]
        XCTAssertNil(LavaLampUtils.parseColor(from: params))
    }

    func testParseColorInvalidHex() {
        let params = [URLQueryItem(name: "hex", value: "ZZZZZZ")]
        XCTAssertNil(LavaLampUtils.parseColor(from: params))
    }

    // MARK: - parseSpeed

    func testParseSpeedSlow() {
        let params = [URLQueryItem(name: "value", value: "slow")]
        XCTAssertEqual(LavaLampUtils.parseSpeed(from: params), 0.25)
    }

    func testParseSpeedNormal() {
        let params = [URLQueryItem(name: "value", value: "normal")]
        XCTAssertEqual(LavaLampUtils.parseSpeed(from: params), 0.5)
    }

    func testParseSpeedFast() {
        let params = [URLQueryItem(name: "value", value: "fast")]
        XCTAssertEqual(LavaLampUtils.parseSpeed(from: params), 1.0)
    }

    func testParseSpeedCaseInsensitive() {
        XCTAssertEqual(LavaLampUtils.parseSpeed(from: [URLQueryItem(name: "value", value: "SLOW")]), 0.25)
        XCTAssertEqual(LavaLampUtils.parseSpeed(from: [URLQueryItem(name: "value", value: "Normal")]), 0.5)
        XCTAssertEqual(LavaLampUtils.parseSpeed(from: [URLQueryItem(name: "value", value: "FAST")]), 1.0)
    }

    func testParseSpeedNumeric() {
        let params = [URLQueryItem(name: "value", value: "0.75")]
        XCTAssertEqual(LavaLampUtils.parseSpeed(from: params), 0.75)
    }

    func testParseSpeedZero() {
        let params = [URLQueryItem(name: "value", value: "0")]
        XCTAssertEqual(LavaLampUtils.parseSpeed(from: params), 0.0)
    }

    func testParseSpeedLargeValue() {
        let params = [URLQueryItem(name: "value", value: "5.0")]
        XCTAssertEqual(LavaLampUtils.parseSpeed(from: params), 5.0)
    }

    func testParseSpeedMissingParam() {
        let params = [URLQueryItem(name: "other", value: "1.0")]
        XCTAssertNil(LavaLampUtils.parseSpeed(from: params))
    }

    func testParseSpeedEmptyParams() {
        XCTAssertNil(LavaLampUtils.parseSpeed(from: []))
    }

    func testParseSpeedInvalidString() {
        let params = [URLQueryItem(name: "value", value: "invalid")]
        XCTAssertNil(LavaLampUtils.parseSpeed(from: params))
    }

    func testParseSpeedNilValue() {
        let params = [URLQueryItem(name: "value", value: nil)]
        XCTAssertNil(LavaLampUtils.parseSpeed(from: params))
    }
}
