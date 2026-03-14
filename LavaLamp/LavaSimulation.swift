import Foundation
import CoreGraphics

struct Blob {
    var x: CGFloat
    var y: CGFloat
    var radius: CGFloat
    var dx: CGFloat
    var dy: CGFloat
    var temperature: CGFloat // 0 = cold, 1 = hot
}

class LavaSimulation {
    var blobs: [Blob]
    let gridWidth: Int
    let gridHeight: Int

    private let ambientTemp: CGFloat = 0.5
    private let heatingRate: CGFloat = 0.8
    private let coolingRate: CGFloat = 0.6
    private let buoyancyStrength: CGFloat = 40.0
    private let dragFactor: CGFloat = 0.98
    private let driftStrength: CGFloat = 3.0

    init(gridWidth: Int = LampConfig.gridWidth, gridHeight: Int = LampConfig.gridHeight, blobCount: Int = LampConfig.defaultBlobCount) {
        self.gridWidth = gridWidth
        self.gridHeight = gridHeight
        self.blobs = []

        for _ in 0..<blobCount {
            let blob = Blob(
                x: CGFloat.random(in: 10...CGFloat(gridWidth - 10)),
                y: CGFloat.random(in: 20...CGFloat(gridHeight - 20)),
                radius: CGFloat.random(in: 6...10),
                dx: CGFloat.random(in: -1...1),
                dy: CGFloat.random(in: -2...2),
                temperature: CGFloat.random(in: 0.3...0.7)
            )
            blobs.append(blob)
        }
    }

    func update(dt: CGFloat, speedMultiplier: CGFloat = 1.0) {
        let effectiveDt = dt * speedMultiplier

        let glassTop = CGFloat(LampConfig.glassTop)
        let glassBottom = CGFloat(LampConfig.glassBottom)

        for i in 0..<blobs.count {
            // Heating near bottom, cooling near top
            let normalizedY = (blobs[i].y - glassTop) / (glassBottom - glassTop)
            if normalizedY > 0.7 {
                blobs[i].temperature += heatingRate * effectiveDt * (normalizedY - 0.7) / 0.3
            }
            if normalizedY < 0.3 {
                blobs[i].temperature -= coolingRate * effectiveDt * (0.3 - normalizedY) / 0.3
            }

            // Drift toward ambient
            blobs[i].temperature += (ambientTemp - blobs[i].temperature) * 0.1 * effectiveDt
            blobs[i].temperature = max(0, min(1, blobs[i].temperature))

            // Buoyancy
            let tempDiff = blobs[i].temperature - ambientTemp
            blobs[i].dy -= tempDiff * buoyancyStrength * effectiveDt

            // Random horizontal drift
            blobs[i].dx += CGFloat.random(in: -driftStrength...driftStrength) * effectiveDt

            // Drag
            blobs[i].dx *= pow(dragFactor, effectiveDt * 60)
            blobs[i].dy *= pow(dragFactor, effectiveDt * 60)

            // Clamp velocity
            blobs[i].dx = max(-15, min(15, blobs[i].dx))
            blobs[i].dy = max(-20, min(20, blobs[i].dy))

            // Move
            blobs[i].x += blobs[i].dx * effectiveDt
            blobs[i].y += blobs[i].dy * effectiveDt

            // Wall collisions (glass shape)
            let centerX = CGFloat(gridWidth) / 2
            let hw = LampConfig.glassHalfWidth(atRow: blobs[i].y)
            let leftBound = centerX - hw + blobs[i].radius * 0.5
            let rightBound = centerX + hw - blobs[i].radius * 0.5

            if blobs[i].x < leftBound {
                blobs[i].x = leftBound
                blobs[i].dx = abs(blobs[i].dx) * 0.5
            }
            if blobs[i].x > rightBound {
                blobs[i].x = rightBound
                blobs[i].dx = -abs(blobs[i].dx) * 0.5
            }

            // Top/bottom bounds
            let topBound = glassTop + blobs[i].radius * 0.5
            let bottomBound = glassBottom - blobs[i].radius * 0.5

            if blobs[i].y < topBound {
                blobs[i].y = topBound
                blobs[i].dy = abs(blobs[i].dy) * 0.3
                blobs[i].temperature = max(blobs[i].temperature, 0.1)
            }
            if blobs[i].y > bottomBound {
                blobs[i].y = bottomBound
                blobs[i].dy = -abs(blobs[i].dy) * 0.3
                blobs[i].temperature = min(blobs[i].temperature, 0.9)
            }
        }
    }
}
