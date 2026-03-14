import SpriteKit
import AppKit

class LavaLampScene: SKScene {
    private var simulation: LavaSimulation!
    private var renderer: PixelGridRenderer!
    private var textureNode: SKSpriteNode!

    private let gridWidth = 48
    private let gridHeight = 120
    private let pixelScale: CGFloat = 4.0

    var lavaColor: NSColor = .orange {
        didSet { needsRedraw = true }
    }
    var speedMultiplier: CGFloat = 1.0
    var targetFrameRate: CGFloat = 15.0

    private var needsRedraw = true
    private var accumulator: TimeInterval = 0
    private var lastUpdateTime: TimeInterval = 0

    override func didMove(to view: SKView) {
        backgroundColor = .clear
        view.allowsTransparency = true

        simulation = LavaSimulation(gridWidth: gridWidth, gridHeight: gridHeight, blobCount: 5)
        renderer = PixelGridRenderer(width: gridWidth, height: gridHeight)

        let nodeWidth = CGFloat(gridWidth) * pixelScale
        let nodeHeight = CGFloat(gridHeight) * pixelScale
        textureNode = SKSpriteNode(color: .clear, size: CGSize(width: nodeWidth, height: nodeHeight))
        textureNode.position = CGPoint(x: size.width / 2, y: size.height / 2)
        textureNode.texture?.filteringMode = .nearest // crisp pixels
        addChild(textureNode)
    }

    override func update(_ currentTime: TimeInterval) {
        if lastUpdateTime == 0 {
            lastUpdateTime = currentTime
            return
        }

        let dt = currentTime - lastUpdateTime
        lastUpdateTime = currentTime

        accumulator += dt
        let frameInterval = 1.0 / TimeInterval(targetFrameRate)

        if accumulator >= frameInterval {
            accumulator -= frameInterval

            // Update simulation
            simulation.update(dt: CGFloat(frameInterval), speedMultiplier: speedMultiplier)

            // Render to pixel buffer
            let pixels = renderer.render(simulation: simulation, lavaColor: lavaColor)

            // Create texture from pixel buffer
            let texture = createTexture(from: pixels)
            textureNode.texture = texture
            textureNode.texture?.filteringMode = .nearest
        }
    }

    private func createTexture(from pixels: [PixelColor]) -> SKTexture {
        var rgba = [UInt8](repeating: 0, count: gridWidth * gridHeight * 4)

        for y in 0..<gridHeight {
            for x in 0..<gridWidth {
                // Flip Y: SpriteKit textures have origin at bottom-left
                let srcIdx = y * gridWidth + x
                let dstY = gridHeight - 1 - y
                let dstIdx = (dstY * gridWidth + x) * 4

                rgba[dstIdx] = pixels[srcIdx].r
                rgba[dstIdx + 1] = pixels[srcIdx].g
                rgba[dstIdx + 2] = pixels[srcIdx].b
                rgba[dstIdx + 3] = pixels[srcIdx].a
            }
        }

        let data = Data(rgba)
        let texture = SKTexture(
            data: data,
            size: CGSize(width: gridWidth, height: gridHeight)
        )
        texture.filteringMode = .nearest
        return texture
    }
}
