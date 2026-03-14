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

    // MARK: - URL Scheme Handling

    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            handleURL(url)
        }
    }

    private func handleURL(_ url: URL) {
        guard url.scheme == "lavalamp" else { return }
        let command = url.host ?? ""
        let params = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []

        switch command {
        case "start":
            scene.isPaused = false

        case "stop":
            scene.isPaused = true

        case "toggle":
            scene.isPaused.toggle()

        case "set-color":
            if let color = parseColor(from: params) {
                scene.lavaColor = color
                saveColor(color)
            }

        case "random-color":
            let color = Self.randomHarmoniousColor()
            scene.lavaColor = color
            saveColor(color)

        case "set-speed":
            if let speed = parseSpeed(from: params) {
                scene.speedMultiplier = speed
                UserDefaults.standard.set(Double(speed), forKey: kSpeed)
            }

        case "quit":
            NSApplication.shared.terminate(nil)

        default:
            break
        }
    }

    private func parseColor(from params: [URLQueryItem]) -> NSColor? {
        // Try hex first: ?hex=FF6600 or ?hex=#FF6600
        if let hex = params.first(where: { $0.name == "hex" })?.value {
            return colorFromHex(hex)
        }
        // Try r,g,b (0.0-1.0): ?r=0.2&g=0.4&b=1.0
        if let rStr = params.first(where: { $0.name == "r" })?.value,
           let gStr = params.first(where: { $0.name == "g" })?.value,
           let bStr = params.first(where: { $0.name == "b" })?.value,
           let r = Double(rStr), let g = Double(gStr), let b = Double(bStr) {
            return NSColor(red: CGFloat(r), green: CGFloat(g), blue: CGFloat(b), alpha: 1.0)
        }
        return nil
    }

    private func colorFromHex(_ hex: String) -> NSColor? {
        var h = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if h.hasPrefix("#") { h.removeFirst() }
        guard h.count == 6, let val = UInt64(h, radix: 16) else { return nil }
        let r = CGFloat((val >> 16) & 0xFF) / 255.0
        let g = CGFloat((val >> 8) & 0xFF) / 255.0
        let b = CGFloat(val & 0xFF) / 255.0
        return NSColor(red: r, green: g, blue: b, alpha: 1.0)
    }

    private func parseSpeed(from params: [URLQueryItem]) -> CGFloat? {
        guard let value = params.first(where: { $0.name == "value" })?.value else { return nil }
        switch value.lowercased() {
        case "slow": return 0.25
        case "normal": return 0.5
        case "fast": return 1.0
        default:
            if let f = Double(value) { return CGFloat(f) }
            return nil
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
