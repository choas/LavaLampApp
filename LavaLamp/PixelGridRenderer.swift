import Foundation
import CoreGraphics
import AppKit

struct PixelColor {
    var r: UInt8
    var g: UInt8
    var b: UInt8
    var a: UInt8
}

class PixelGridRenderer {
    let width: Int
    let height: Int
    private var pixelBuffer: [PixelColor]

    init(width: Int = LampConfig.gridWidth, height: Int = LampConfig.gridHeight) {
        self.width = width
        self.height = height
        self.pixelBuffer = Array(repeating: PixelColor(r: 0, g: 0, b: 0, a: 0), count: width * height)
    }

    func glassHalfWidth(atRow y: Int) -> CGFloat {
        return LampConfig.glassHalfWidth(atRow: CGFloat(y))
    }

    func render(simulation: LavaSimulation, lavaColor: NSColor) -> [PixelColor] {
        let centerX = CGFloat(width) / 2

        // Extract lava color components
        let ciColor = lavaColor.usingColorSpace(.sRGB) ?? lavaColor
        let lr = UInt8(min(255, max(0, ciColor.redComponent * 255)))
        let lg = UInt8(min(255, max(0, ciColor.greenComponent * 255)))
        let lb = UInt8(min(255, max(0, ciColor.blueComponent * 255)))

        // Brighter highlight color
        let hr = UInt8(min(255, Int(lr) + 60))
        let hg = UInt8(min(255, Int(lg) + 60))
        let hb = UInt8(min(255, Int(lb) + 60))

        // Darker shade for depth
        let dr = UInt8(max(0, Int(lr) - 40))
        let dg = UInt8(max(0, Int(lg) - 40))
        let db = UInt8(max(0, Int(lb) - 40))

        // Clear buffer
        for i in 0..<pixelBuffer.count {
            pixelBuffer[i] = PixelColor(r: 0, g: 0, b: 0, a: 0)
        }

        let threshold: CGFloat = 1.0
        let glowLow: CGFloat = 0.6
        let glowHigh: CGFloat = 1.4

        // Render lava using metaball field
        for y in LampConfig.glassTop..<LampConfig.glassBottom {
            let hw = glassHalfWidth(atRow: y)
            let left = Int(centerX - hw) + 1
            let right = Int(centerX + hw) - 1

            for x in left..<right {
                var field: CGFloat = 0
                for blob in simulation.blobs {
                    let dx = CGFloat(x) - blob.x
                    let dy = CGFloat(y) - blob.y
                    let distSq = dx * dx + dy * dy
                    let clampedDistSq = max(distSq, 0.01)
                    field += (blob.radius * blob.radius) / clampedDistSq
                }

                let idx = y * width + x
                if field > glowHigh {
                    // Core lava
                    pixelBuffer[idx] = PixelColor(r: lr, g: lg, b: lb, a: 255)
                } else if field > threshold {
                    // Bright edge / highlight
                    pixelBuffer[idx] = PixelColor(r: hr, g: hg, b: hb, a: 255)
                } else if field > glowLow {
                    // Outer glow
                    let alpha = UInt8((field - glowLow) / (threshold - glowLow) * 180)
                    pixelBuffer[idx] = PixelColor(r: dr, g: dg, b: db, a: alpha)
                }
            }
        }

        // Draw glass outline
        drawGlassOutline(centerX: centerX)

        // Draw cap
        drawCap(centerX: centerX)

        // Draw base
        drawBase(centerX: centerX)

        return pixelBuffer
    }

    private func setPixel(x: Int, y: Int, color: PixelColor) {
        guard x >= 0, x < width, y >= 0, y < height else { return }
        pixelBuffer[y * width + x] = color
    }

    private func drawGlassOutline(centerX: CGFloat) {
        let outlineColor = PixelColor(r: 180, g: 200, b: 210, a: 160)

        for y in LampConfig.glassTop...LampConfig.glassBottom {
            let hw = glassHalfWidth(atRow: y)
            let left = Int(centerX - hw)
            let right = Int(centerX + hw)
            setPixel(x: left, y: y, color: outlineColor)
            setPixel(x: right, y: y, color: outlineColor)
        }

        // Top edge connecting to cap
        let topHw = Int(glassHalfWidth(atRow: LampConfig.glassTop))
        for x in (Int(centerX) - topHw)...(Int(centerX) + topHw) {
            setPixel(x: x, y: LampConfig.glassTop, color: outlineColor)
        }

        // Bottom edge connecting to base
        let bottomHw = Int(glassHalfWidth(atRow: LampConfig.glassBottom))
        for x in (Int(centerX) - bottomHw)...(Int(centerX) + bottomHw) {
            setPixel(x: x, y: LampConfig.glassBottom, color: outlineColor)
        }
    }

    private func drawCap(centerX: CGFloat) {
        let metalColor = PixelColor(r: 140, g: 140, b: 150, a: 255)
        let metalHighlight = PixelColor(r: 180, g: 180, b: 190, a: 255)

        let capHalfWidth: Int = 8
        let topKnobHalf: Int = 3

        // Main cap body
        for y in (LampConfig.capTop + 2)..<LampConfig.capBottom {
            for x in (Int(centerX) - capHalfWidth)...(Int(centerX) + capHalfWidth) {
                let color = (y == LampConfig.capTop + 2) ? metalHighlight : metalColor
                setPixel(x: x, y: y, color: color)
            }
        }

        // Top knob
        for y in LampConfig.capTop...(LampConfig.capTop + 2) {
            for x in (Int(centerX) - topKnobHalf)...(Int(centerX) + topKnobHalf) {
                setPixel(x: x, y: y, color: metalHighlight)
            }
        }
    }

    private func drawBase(centerX: CGFloat) {
        let metalColor = PixelColor(r: 130, g: 130, b: 140, a: 255)
        let metalHighlight = PixelColor(r: 160, g: 160, b: 170, a: 255)

        // Base widens toward bottom
        for y in LampConfig.baseTop...LampConfig.baseBottom {
            let progress = CGFloat(y - LampConfig.baseTop) / CGFloat(LampConfig.baseBottom - LampConfig.baseTop)
            let halfWidth = Int(12 + progress * 6)
            for x in (Int(centerX) - halfWidth)...(Int(centerX) + halfWidth) {
                let color = (y == LampConfig.baseTop) ? metalHighlight : metalColor
                setPixel(x: x, y: y, color: color)
            }
        }
    }
}
