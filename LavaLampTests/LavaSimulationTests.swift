import XCTest
@testable import LavaLamp

final class LavaSimulationTests: XCTestCase {

    // MARK: - Initialization

    func testInitCreatesCorrectBlobCount() {
        let sim = LavaSimulation(gridWidth: 48, gridHeight: 120, blobCount: 5)
        XCTAssertEqual(sim.blobs.count, 5)
    }

    func testInitWithZeroBlobs() {
        let sim = LavaSimulation(gridWidth: 48, gridHeight: 120, blobCount: 0)
        XCTAssertEqual(sim.blobs.count, 0)
    }

    func testInitWithCustomBlobCount() {
        let sim = LavaSimulation(gridWidth: 48, gridHeight: 120, blobCount: 10)
        XCTAssertEqual(sim.blobs.count, 10)
    }

    func testInitBlobsWithinBounds() {
        let sim = LavaSimulation(gridWidth: 48, gridHeight: 120, blobCount: 20)
        for blob in sim.blobs {
            XCTAssertGreaterThanOrEqual(blob.x, 10)
            XCTAssertLessThanOrEqual(blob.x, 38) // gridWidth - 10
            XCTAssertGreaterThanOrEqual(blob.y, 20)
            XCTAssertLessThanOrEqual(blob.y, 100) // gridHeight - 20
            XCTAssertGreaterThanOrEqual(blob.radius, 6)
            XCTAssertLessThanOrEqual(blob.radius, 10)
            XCTAssertGreaterThanOrEqual(blob.temperature, 0.3)
            XCTAssertLessThanOrEqual(blob.temperature, 0.7)
        }
    }

    func testGridDimensionsStored() {
        let sim = LavaSimulation(gridWidth: 60, gridHeight: 150, blobCount: 1)
        XCTAssertEqual(sim.gridWidth, 60)
        XCTAssertEqual(sim.gridHeight, 150)
    }

    // MARK: - Temperature Dynamics

    func testTemperatureClampedBetween0And1() {
        let sim = LavaSimulation(gridWidth: 48, gridHeight: 120, blobCount: 1)
        // Force extreme temperature
        sim.blobs[0].temperature = 2.0
        sim.blobs[0].y = CGFloat(LampConfig.glassTop + 5)  // near top -> cooling zone
        sim.update(dt: 0.1, speedMultiplier: 1.0)
        XCTAssertLessThanOrEqual(sim.blobs[0].temperature, 1.0)

        sim.blobs[0].temperature = -1.0
        sim.update(dt: 0.1, speedMultiplier: 1.0)
        XCTAssertGreaterThanOrEqual(sim.blobs[0].temperature, 0.0)
    }

    func testHeatingNearBottom() {
        let sim = LavaSimulation(gridWidth: 48, gridHeight: 120, blobCount: 1)
        let glassBottom = CGFloat(LampConfig.glassBottom)
        // Place blob near bottom (normalizedY > 0.7)
        sim.blobs[0].y = glassBottom - 5
        sim.blobs[0].temperature = 0.5
        sim.blobs[0].dx = 0
        sim.blobs[0].dy = 0

        let tempBefore = sim.blobs[0].temperature
        sim.update(dt: 0.066, speedMultiplier: 1.0)
        XCTAssertGreaterThan(sim.blobs[0].temperature, tempBefore,
            "Blob near bottom should be heated")
    }

    func testCoolingNearTop() {
        let sim = LavaSimulation(gridWidth: 48, gridHeight: 120, blobCount: 1)
        let glassTop = CGFloat(LampConfig.glassTop)
        // Place blob near top (normalizedY < 0.3)
        sim.blobs[0].y = glassTop + 5
        sim.blobs[0].temperature = 0.5
        sim.blobs[0].dx = 0
        sim.blobs[0].dy = 0

        let tempBefore = sim.blobs[0].temperature
        sim.update(dt: 0.066, speedMultiplier: 1.0)
        XCTAssertLessThan(sim.blobs[0].temperature, tempBefore,
            "Blob near top should be cooled")
    }

    // MARK: - Buoyancy

    func testHotBlobRises() {
        let sim = LavaSimulation(gridWidth: 48, gridHeight: 120, blobCount: 1)
        let center = CGFloat(LampConfig.glassTop + LampConfig.glassBottom) / 2
        sim.blobs[0].y = center
        sim.blobs[0].x = 24
        sim.blobs[0].temperature = 0.9  // hot -> should rise (dy decreases, since y increases downward)
        sim.blobs[0].dx = 0
        sim.blobs[0].dy = 0

        sim.update(dt: 0.066, speedMultiplier: 1.0)
        // Buoyancy: dy -= (temp - 0.5) * 40 * dt
        // With temp=0.9: dy -= 0.4 * 40 * 0.066 = -1.056
        // Hot blob should get negative dy (moving upward in screen coords)
        XCTAssertLessThan(sim.blobs[0].dy, 0, "Hot blob should rise (negative dy)")
    }

    func testColdBlobSinks() {
        let sim = LavaSimulation(gridWidth: 48, gridHeight: 120, blobCount: 1)
        let center = CGFloat(LampConfig.glassTop + LampConfig.glassBottom) / 2
        sim.blobs[0].y = center
        sim.blobs[0].x = 24
        sim.blobs[0].temperature = 0.1  // cold -> should sink
        sim.blobs[0].dx = 0
        sim.blobs[0].dy = 0

        sim.update(dt: 0.066, speedMultiplier: 1.0)
        XCTAssertGreaterThan(sim.blobs[0].dy, 0, "Cold blob should sink (positive dy)")
    }

    // MARK: - Velocity Clamping

    func testVelocityClampedHorizontal() {
        let sim = LavaSimulation(gridWidth: 48, gridHeight: 120, blobCount: 1)
        sim.blobs[0].dx = 100
        sim.blobs[0].dy = 0
        sim.blobs[0].y = CGFloat(LampConfig.glassTop + LampConfig.glassBottom) / 2
        sim.blobs[0].x = 24

        sim.update(dt: 0.066, speedMultiplier: 1.0)
        XCTAssertLessThanOrEqual(sim.blobs[0].dx, 15)
        XCTAssertGreaterThanOrEqual(sim.blobs[0].dx, -15)
    }

    func testVelocityClampedVertical() {
        let sim = LavaSimulation(gridWidth: 48, gridHeight: 120, blobCount: 1)
        sim.blobs[0].dy = 100
        sim.blobs[0].dx = 0
        sim.blobs[0].y = CGFloat(LampConfig.glassTop + LampConfig.glassBottom) / 2
        sim.blobs[0].x = 24

        sim.update(dt: 0.066, speedMultiplier: 1.0)
        XCTAssertLessThanOrEqual(sim.blobs[0].dy, 20)
        XCTAssertGreaterThanOrEqual(sim.blobs[0].dy, -20)
    }

    // MARK: - Wall Collisions

    func testBlobStaysWithinGlassBoundsVertically() {
        let sim = LavaSimulation(gridWidth: 48, gridHeight: 120, blobCount: 1)
        // Try to push blob above glass
        sim.blobs[0].y = CGFloat(LampConfig.glassTop) - 20
        sim.blobs[0].dy = -10
        sim.blobs[0].dx = 0
        sim.blobs[0].x = 24

        sim.update(dt: 0.066, speedMultiplier: 1.0)
        let topBound = CGFloat(LampConfig.glassTop) + sim.blobs[0].radius * 0.5
        XCTAssertGreaterThanOrEqual(sim.blobs[0].y, topBound,
            "Blob should not go above glass top")
    }

    func testBlobStaysWithinGlassBoundsBottom() {
        let sim = LavaSimulation(gridWidth: 48, gridHeight: 120, blobCount: 1)
        // Try to push blob below glass
        sim.blobs[0].y = CGFloat(LampConfig.glassBottom) + 20
        sim.blobs[0].dy = 10
        sim.blobs[0].dx = 0
        sim.blobs[0].x = 24

        sim.update(dt: 0.066, speedMultiplier: 1.0)
        let bottomBound = CGFloat(LampConfig.glassBottom) - sim.blobs[0].radius * 0.5
        XCTAssertLessThanOrEqual(sim.blobs[0].y, bottomBound,
            "Blob should not go below glass bottom")
    }

    func testTopBounceReversesDy() {
        let sim = LavaSimulation(gridWidth: 48, gridHeight: 120, blobCount: 1)
        sim.blobs[0].y = CGFloat(LampConfig.glassTop) - 5
        sim.blobs[0].dy = -10
        sim.blobs[0].dx = 0
        sim.blobs[0].x = 24

        sim.update(dt: 0.066, speedMultiplier: 1.0)
        XCTAssertGreaterThanOrEqual(sim.blobs[0].dy, 0,
            "Blob bouncing off top should have non-negative dy")
    }

    func testBottomBounceReversesDy() {
        let sim = LavaSimulation(gridWidth: 48, gridHeight: 120, blobCount: 1)
        sim.blobs[0].y = CGFloat(LampConfig.glassBottom) + 5
        sim.blobs[0].dy = 10
        sim.blobs[0].dx = 0
        sim.blobs[0].x = 24

        sim.update(dt: 0.066, speedMultiplier: 1.0)
        XCTAssertLessThanOrEqual(sim.blobs[0].dy, 0,
            "Blob bouncing off bottom should have non-positive dy")
    }

    func testTopBounceTemperatureFloor() {
        let sim = LavaSimulation(gridWidth: 48, gridHeight: 120, blobCount: 1)
        sim.blobs[0].y = CGFloat(LampConfig.glassTop) - 5
        sim.blobs[0].temperature = 0.0
        sim.blobs[0].dx = 0
        sim.blobs[0].dy = 0
        sim.blobs[0].x = 24

        sim.update(dt: 0.066, speedMultiplier: 1.0)
        XCTAssertGreaterThanOrEqual(sim.blobs[0].temperature, 0.1,
            "Temperature at top should be at least 0.1")
    }

    func testBottomBounceTemperatureCeiling() {
        let sim = LavaSimulation(gridWidth: 48, gridHeight: 120, blobCount: 1)
        sim.blobs[0].y = CGFloat(LampConfig.glassBottom) + 5
        sim.blobs[0].temperature = 1.0
        sim.blobs[0].dx = 0
        sim.blobs[0].dy = 0
        sim.blobs[0].x = 24

        sim.update(dt: 0.066, speedMultiplier: 1.0)
        XCTAssertLessThanOrEqual(sim.blobs[0].temperature, 0.9,
            "Temperature at bottom should be at most 0.9")
    }

    // MARK: - Speed Multiplier

    func testSpeedMultiplierZeroFreezes() {
        let sim = LavaSimulation(gridWidth: 48, gridHeight: 120, blobCount: 1)
        let center = CGFloat(LampConfig.glassTop + LampConfig.glassBottom) / 2
        sim.blobs[0].y = center
        sim.blobs[0].x = 24
        sim.blobs[0].dx = 0
        sim.blobs[0].dy = 0
        sim.blobs[0].temperature = 0.5

        let xBefore = sim.blobs[0].x
        let yBefore = sim.blobs[0].y
        sim.update(dt: 0.066, speedMultiplier: 0.0)

        // With zero speed, effectiveDt = 0, so position should barely change
        // (only random drift scaled by effectiveDt = 0)
        XCTAssertEqual(sim.blobs[0].x, xBefore, accuracy: 0.001)
        XCTAssertEqual(sim.blobs[0].y, yBefore, accuracy: 0.001)
    }

    func testSpeedMultiplierScalesMovement() {
        // Run two simulations with different speed multipliers
        let sim1 = LavaSimulation(gridWidth: 48, gridHeight: 120, blobCount: 1)
        let sim2 = LavaSimulation(gridWidth: 48, gridHeight: 120, blobCount: 1)

        let center = CGFloat(LampConfig.glassTop + LampConfig.glassBottom) / 2
        // Set identical initial state
        let blob = Blob(x: 24, y: center, radius: 8, dx: 0, dy: 5, temperature: 0.8)
        sim1.blobs[0] = blob
        sim2.blobs[0] = blob

        sim1.update(dt: 0.066, speedMultiplier: 0.5)
        sim2.update(dt: 0.066, speedMultiplier: 2.0)

        // Higher speed multiplier should cause larger displacement
        // (ignoring random drift)
        let dy1 = abs(sim1.blobs[0].y - center)
        let dy2 = abs(sim2.blobs[0].y - center)
        XCTAssertGreaterThan(dy2, dy1,
            "Higher speed should produce larger displacement")
    }

    // MARK: - Drag

    func testDragReducesVelocity() {
        let sim = LavaSimulation(gridWidth: 48, gridHeight: 120, blobCount: 1)
        let center = CGFloat(LampConfig.glassTop + LampConfig.glassBottom) / 2
        sim.blobs[0].y = center
        sim.blobs[0].x = 24
        sim.blobs[0].dx = 10
        sim.blobs[0].dy = 10
        sim.blobs[0].temperature = 0.5  // ambient, no buoyancy

        sim.update(dt: 0.066, speedMultiplier: 1.0)

        // Drag (0.98^(dt*60)) should reduce velocity magnitude
        XCTAssertLessThan(abs(sim.blobs[0].dx), 10,
            "Drag should reduce horizontal velocity")
    }

    // MARK: - Update with no blobs

    func testUpdateWithNoBlobsDoesNotCrash() {
        let sim = LavaSimulation(gridWidth: 48, gridHeight: 120, blobCount: 0)
        sim.update(dt: 0.066, speedMultiplier: 1.0)
        XCTAssertEqual(sim.blobs.count, 0)
    }
}
