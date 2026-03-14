import AppKit
import SpriteKit

class AppDelegate: NSObject, NSApplicationDelegate {
    private var window: TransparentWindow!
    private var scene: LavaLampScene!
    private var menuBarController: MenuBarController!

    private var pixelScale: CGFloat = LampConfig.defaultPixelScale

    // UserDefaults keys
    private let kWindowX = "windowPositionX"
    private let kWindowY = "windowPositionY"
    private let kLavaColorR = "lavaColorR"
    private let kLavaColorG = "lavaColorG"
    private let kLavaColorB = "lavaColorB"
    private let kSpeed = "speed"
    private let kPixelScale = "pixelScale"

    func applicationDidFinishLaunching(_ notification: Notification) {
        loadSettings()
        setupWindow()
        setupScene()
        setupMenuBar()
        setupClickHandler()
        restoreWindowPosition()
    }

    private func loadSettings() {
        let defaults = UserDefaults.standard
        if defaults.object(forKey: kPixelScale) != nil {
            pixelScale = CGFloat(defaults.double(forKey: kPixelScale))
        }
    }

    private func setupWindow() {
        let windowWidth = CGFloat(LampConfig.gridWidth) * pixelScale
        let windowHeight = CGFloat(LampConfig.gridHeight) * pixelScale

        let screenFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 800, height: 600)
        let windowRect = NSRect(
            x: screenFrame.maxX - windowWidth - 50,
            y: screenFrame.midY - windowHeight / 2,
            width: windowWidth,
            height: windowHeight
        )

        window = TransparentWindow(contentRect: windowRect)
    }

    private func setupScene() {
        let windowWidth = CGFloat(LampConfig.gridWidth) * pixelScale
        let windowHeight = CGFloat(LampConfig.gridHeight) * pixelScale
        let sceneSize = CGSize(width: windowWidth, height: windowHeight)

        scene = LavaLampScene(size: sceneSize)
        scene.scaleMode = .aspectFill
        scene.backgroundColor = .clear

        // Load saved color
        let defaults = UserDefaults.standard
        if defaults.object(forKey: kLavaColorR) != nil {
            let r = CGFloat(defaults.double(forKey: kLavaColorR))
            let g = CGFloat(defaults.double(forKey: kLavaColorG))
            let b = CGFloat(defaults.double(forKey: kLavaColorB))
            scene.lavaColor = NSColor(red: r, green: g, blue: b, alpha: 1.0)
        }

        if defaults.object(forKey: kSpeed) != nil {
            scene.speedMultiplier = CGFloat(defaults.double(forKey: kSpeed))
        }

        let skView = SKView(frame: NSRect(x: 0, y: 0, width: windowWidth, height: windowHeight))
        skView.allowsTransparency = true
        skView.presentScene(scene)

        window.contentView = skView
        window.makeKeyAndOrderFront(nil)
    }

    private func setupMenuBar() {
        menuBarController = MenuBarController()
        menuBarController.setup(scene: scene)

        menuBarController.onColorChanged = { [weak self] color in
            self?.scene.lavaColor = color
            self?.saveColor(color)
        }

        menuBarController.onSpeedChanged = { [weak self] speed in
            self?.scene.speedMultiplier = speed
            UserDefaults.standard.set(Double(speed), forKey: self?.kSpeed ?? "speed")
        }

        menuBarController.onSizeChanged = { [weak self] size in
            self?.resizeLamp(scale: size.scale)
        }

        menuBarController.onClickThroughChanged = { [weak self] clickThrough in
            self?.window.ignoresMouseEvents = clickThrough
        }
    }

    private func setupClickHandler() {
        window.onClicked = { [weak self] in
            let color = Self.randomHarmoniousColor()
            self?.scene.lavaColor = color
            self?.saveColor(color)
        }
    }

    private static func randomHarmoniousColor() -> NSColor {
        // Pick a random base hue
        let hue = CGFloat.random(in: 0...1)
        // Keep saturation and brightness in ranges that produce vivid, attractive lava colors
        let saturation = CGFloat.random(in: 0.6...1.0)
        let brightness = CGFloat.random(in: 0.7...1.0)
        return NSColor(hue: hue, saturation: saturation, brightness: brightness, alpha: 1.0)
    }

    private func saveColor(_ color: NSColor) {
        let c = color.usingColorSpace(.sRGB) ?? color
        UserDefaults.standard.set(Double(c.redComponent), forKey: kLavaColorR)
        UserDefaults.standard.set(Double(c.greenComponent), forKey: kLavaColorG)
        UserDefaults.standard.set(Double(c.blueComponent), forKey: kLavaColorB)
    }

    private func restoreWindowPosition() {
        let defaults = UserDefaults.standard
        if defaults.object(forKey: kWindowX) != nil {
            let x = CGFloat(defaults.double(forKey: kWindowX))
            let y = CGFloat(defaults.double(forKey: kWindowY))
            window.setFrameOrigin(NSPoint(x: x, y: y))
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Save window position
        UserDefaults.standard.set(Double(window.frame.origin.x), forKey: kWindowX)
        UserDefaults.standard.set(Double(window.frame.origin.y), forKey: kWindowY)
    }

    private func resizeLamp(scale: CGFloat) {
        pixelScale = scale
        UserDefaults.standard.set(Double(scale), forKey: kPixelScale)

        let newWidth = CGFloat(LampConfig.gridWidth) * scale
        let newHeight = CGFloat(LampConfig.gridHeight) * scale

        // Keep center position
        let oldCenter = NSPoint(
            x: window.frame.midX,
            y: window.frame.midY
        )

        let newRect = NSRect(
            x: oldCenter.x - newWidth / 2,
            y: oldCenter.y - newHeight / 2,
            width: newWidth,
            height: newHeight
        )

        window.setFrame(newRect, display: false)

        // Recreate scene at new size
        let sceneSize = CGSize(width: newWidth, height: newHeight)
        let oldColor = scene.lavaColor
        let oldSpeed = scene.speedMultiplier

        scene = LavaLampScene(size: sceneSize)
        scene.scaleMode = .aspectFill
        scene.backgroundColor = .clear
        scene.lavaColor = oldColor
        scene.speedMultiplier = oldSpeed

        if let skView = window.contentView as? SKView {
            skView.frame = NSRect(x: 0, y: 0, width: newWidth, height: newHeight)
            skView.presentScene(scene)
        }
    }
}
