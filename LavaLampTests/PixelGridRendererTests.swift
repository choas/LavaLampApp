import XCTest
@testable import LavaLamp

final class PixelGridRendererTests: XCTestCase {

    // MARK: - Initialization

    func testInitCreatesCorrectSizedBuffer() {
        let renderer = PixelGridRenderer(width: 48, height: 120)
        XCTAssertEqual(renderer.width, 48)
        XCTAssertEqual(renderer.height, 120)
    }

    func testInitWithCustomDimensions() {
        let renderer = PixelGridRenderer(width: 64, height: 200)
        XCTAssertEqual(renderer.width, 64)
        XCTAssertEqual(renderer.height, 200)
    }

    // MARK: - Rendering

    func testRenderReturnsCorrectSize() {
        let renderer = PixelGridRenderer()
        let sim = LavaSimulation()
        let pixels = renderer.render(simulation: sim, lavaColor: .orange)
        XCTAssertEqual(pixels.count, LampConfig.gridWidth * LampConfig.gridHeight)
    }

    func testRenderProducesNonEmptyOutput() {
        let renderer = PixelGridRenderer()
        let sim = LavaSimulation()
        let pixels = renderer.render(simulation: sim, lavaColor: .orange)

        // At least some pixels should be non-transparent (lava + glass + cap + base)
        let nonTransparent = pixels.filter { $0.a > 0 }
        XCTAssertGreaterThan(nonTransparent.count, 0, "Render should produce visible pixels")
    }

    func testRenderWithDifferentColorsProducesDifferentOutput() {
        let renderer = PixelGridRenderer()
        let sim = LavaSimulation(blobCount: 3)
        // Place blobs at known positions for deterministic output
        for i in 0..<sim.blobs.count {
            sim.blobs[i].x = CGFloat(LampConfig.gridWidth) / 2
            sim.blobs[i].y = CGFloat(LampConfig.glassTop + LampConfig.glassBottom) / 2
            sim.blobs[i].radius = 8
        }

        let pixelsRed = renderer.render(simulation: sim, lavaColor: .red)
        let pixelsBlue = renderer.render(simulation: sim, lavaColor: .blue)

        // Find a pixel with lava (alpha=255) and compare colors
        var foundDifference = false
        for i in 0..<pixelsRed.count {
            if pixelsRed[i].a == 255 && pixelsBlue[i].a == 255 {
                if pixelsRed[i].r != pixelsBlue[i].r || pixelsRed[i].b != pixelsBlue[i].b {
                    foundDifference = true
                    break
                }
            }
        }
        XCTAssertTrue(foundDifference, "Different lava colors should produce different pixel colors")
    }

    func testRenderWithNoBlobsStillDrawsStructure() {
        let renderer = PixelGridRenderer()
        let sim = LavaSimulation(blobCount: 0)
        let pixels = renderer.render(simulation: sim, lavaColor: .orange)

        // Cap, base, and glass outline should still be drawn
        let nonTransparent = pixels.filter { $0.a > 0 }
        XCTAssertGreaterThan(nonTransparent.count, 0,
            "Glass, cap, and base should be drawn even without blobs")
    }

    // MARK: - Glass outline

    func testGlassOutlineIsDrawn() {
        let renderer = PixelGridRenderer()
        let sim = LavaSimulation(blobCount: 0)
        let pixels = renderer.render(simulation: sim, lavaColor: .orange)

        // Check glass outline pixels along the glass boundaries
        let centerX = LampConfig.gridWidth / 2
        let midY = (LampConfig.glassTop + LampConfig.glassBottom) / 2
        let hw = Int(LampConfig.glassHalfWidth(atRow: CGFloat(midY)))
        let leftX = centerX - hw
        let rightX = centerX + hw

        let leftIdx = midY * LampConfig.gridWidth + leftX
        let rightIdx = midY * LampConfig.gridWidth + rightX

        XCTAssertGreaterThan(pixels[leftIdx].a, 0, "Left glass outline should be visible")
        XCTAssertGreaterThan(pixels[rightIdx].a, 0, "Right glass outline should be visible")
    }

    // MARK: - Cap and Base

    func testCapIsDrawn() {
        let renderer = PixelGridRenderer()
        let sim = LavaSimulation(blobCount: 0)
        let pixels = renderer.render(simulation: sim, lavaColor: .orange)

        // Check a pixel in the cap area
        let centerX = LampConfig.gridWidth / 2
        let capY = LampConfig.capTop + 3  // within cap body
        let idx = capY * LampConfig.gridWidth + centerX

        XCTAssertGreaterThan(pixels[idx].a, 0, "Cap should be visible")
    }

    func testBaseIsDrawn() {
        let renderer = PixelGridRenderer()
        let sim = LavaSimulation(blobCount: 0)
        let pixels = renderer.render(simulation: sim, lavaColor: .orange)

        // Check a pixel in the base area
        let centerX = LampConfig.gridWidth / 2
        let baseY = (LampConfig.baseTop + LampConfig.baseBottom) / 2
        let idx = baseY * LampConfig.gridWidth + centerX

        XCTAssertGreaterThan(pixels[idx].a, 0, "Base should be visible")
    }

    // MARK: - Metaball field

    func testLavaBlobCreatesVisiblePixels() {
        let renderer = PixelGridRenderer()
        let sim = LavaSimulation(blobCount: 1)

        // Place blob at center of glass
        let centerX = CGFloat(LampConfig.gridWidth) / 2
        let centerY = CGFloat(LampConfig.glassTop + LampConfig.glassBottom) / 2
        sim.blobs[0] = Blob(x: centerX, y: centerY, radius: 10, dx: 0, dy: 0, temperature: 0.5)

        let pixels = renderer.render(simulation: sim, lavaColor: .red)

        // Pixel at blob center should be opaque
        let idx = Int(centerY) * LampConfig.gridWidth + Int(centerX)
        XCTAssertEqual(pixels[idx].a, 255, "Pixel at blob center should be fully opaque")
    }

    func testLavaColorMatchesInput() {
        let renderer = PixelGridRenderer()
        let sim = LavaSimulation(blobCount: 1)

        let centerX = CGFloat(LampConfig.gridWidth) / 2
        let centerY = CGFloat(LampConfig.glassTop + LampConfig.glassBottom) / 2
        sim.blobs[0] = Blob(x: centerX, y: centerY, radius: 10, dx: 0, dy: 0, temperature: 0.5)

        let lavaColor = NSColor(red: 1.0, green: 0.0, blue: 0.0, alpha: 1.0)
        let pixels = renderer.render(simulation: sim, lavaColor: lavaColor)

        let idx = Int(centerY) * LampConfig.gridWidth + Int(centerX)
        // Core lava should have the red channel maxed
        XCTAssertEqual(pixels[idx].r, 255, "Core lava red should match input color")
        XCTAssertEqual(pixels[idx].g, 0, "Core lava green should match input color")
        XCTAssertEqual(pixels[idx].b, 0, "Core lava blue should match input color")
    }

    // MARK: - Buffer clearing

    func testRenderClearsBufferBetweenCalls() {
        let renderer = PixelGridRenderer()
        let sim = LavaSimulation(blobCount: 1)

        let centerX = CGFloat(LampConfig.gridWidth) / 2
        let centerY = CGFloat(LampConfig.glassTop + LampConfig.glassBottom) / 2
        sim.blobs[0] = Blob(x: centerX, y: centerY, radius: 10, dx: 0, dy: 0, temperature: 0.5)

        // First render with blob at center
        _ = renderer.render(simulation: sim, lavaColor: .red)

        // Move blob away and render again
        sim.blobs[0].y = CGFloat(LampConfig.glassTop + 5)
        sim.blobs[0].x = centerX
        let pixels = renderer.render(simulation: sim, lavaColor: .red)

        // Original center should now be empty (only if not within glow range)
        // The center pixel should have different content than the first render
        // since the blob moved away
        let idx = Int(centerY) * LampConfig.gridWidth + Int(centerX)
        // If blob is far enough away, this should be transparent
        // The blob moved to glassTop+5, which is ~50 pixels away from center
        // With radius 10, the metaball field at 50px away is: 100/2500 = 0.04 < 0.6 threshold
        XCTAssertEqual(pixels[idx].a, 0,
            "Buffer should be cleared between renders; old blob position should be transparent")
    }

    // MARK: - Glass half-width delegate

    func testRendererGlassHalfWidthMatchesConfig() {
        let renderer = PixelGridRenderer()
        for y in LampConfig.glassTop...LampConfig.glassBottom {
            let rendererHW = renderer.glassHalfWidth(atRow: y)
            let configHW = LampConfig.glassHalfWidth(atRow: CGFloat(y))
            XCTAssertEqual(rendererHW, configHW, accuracy: 0.001,
                "Renderer glass half-width should match LampConfig at row \(y)")
        }
    }
}
