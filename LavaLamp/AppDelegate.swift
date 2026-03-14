import AppKit
import SpriteKit

class AppDelegate: NSObject, NSApplicationDelegate {
    private var window: TransparentWindow!
    private var scene: LavaLampScene!
    private var menuBarController: MenuBarController!

    private var pixelScale: CGFloat = LampConfig.defaultPixelScale
    private var titleLabel: NSTextField!
    private var titleText: String = ""
    private var titleFontName: String = "Helvetica"
    private var titleFontSize: CGFloat = 12.0
    private var httpServer = HTTPServer()
    private var titleTimer: Timer?

    // UserDefaults keys
    private let kWindowX = "windowPositionX"
    private let kWindowY = "windowPositionY"
    private let kLavaColorR = "lavaColorR"
    private let kLavaColorG = "lavaColorG"
    private let kLavaColorB = "lavaColorB"
    private let kSpeed = "speed"
    private let kPixelScale = "pixelScale"
    private let kTitle = "title"
    private let kTitleFont = "titleFont"
    private let kTitleFontSize = "titleFontSize"
    private let kHTTPPort = "httpPort"

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Register URL scheme handler directly via Apple Events
        // (application(_:open:) is not called in SwiftUI lifecycle apps)
        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(handleGetURLEvent(_:withReplyEvent:)),
            forEventClass: AEEventClass(kInternetEventClass),
            andEventID: AEEventID(kAEGetURL)
        )

        loadSettings()
        setupWindow()
        setupScene()
        setupMenuBar()
        setupClickHandler()
        restoreWindowPosition()
    }

    @objc private func handleGetURLEvent(_ event: NSAppleEventDescriptor, withReplyEvent replyEvent: NSAppleEventDescriptor) {
        guard let urlString = event.paramDescriptor(forKeyword: AEKeyword(keyDirectObject))?.stringValue,
              let url = URL(string: urlString) else { return }
        handleURL(url)
    }

    private func loadSettings() {
        let defaults = UserDefaults.standard
        if defaults.object(forKey: kPixelScale) != nil {
            pixelScale = CGFloat(defaults.double(forKey: kPixelScale))
        }
        if let saved = defaults.string(forKey: kTitle) {
            titleText = saved
        }
        if let saved = defaults.string(forKey: kTitleFont) {
            titleFontName = saved
        }
        if defaults.object(forKey: kTitleFontSize) != nil {
            titleFontSize = CGFloat(defaults.double(forKey: kTitleFontSize))
        }

        // Restore HTTP server if a port was saved
        let savedPort = defaults.integer(forKey: kHTTPPort)
        if savedPort > 0 {
            startHTTPServer(port: UInt16(savedPort))
        }
    }

    private func startHTTPServer(port: UInt16) {
        httpServer.onCommand = { [weak self] url in
            self?.handleURL(url)
        }
        httpServer.onStatus = { [weak self] in
            self?.getCurrentStatus() ?? [:]
        }
        do {
            try httpServer.start(port: port)
            UserDefaults.standard.set(Int(port), forKey: kHTTPPort)
        } catch {
            print("Failed to start HTTP server: \(error)")
        }
    }

    private func getCurrentStatus() -> [String: Any] {
        let c = scene.lavaColor.usingColorSpace(.sRGB) ?? scene.lavaColor
        return [
            "color": [
                "r": Double(c.redComponent),
                "g": Double(c.greenComponent),
                "b": Double(c.blueComponent)
            ],
            "speed": Double(scene.speedMultiplier),
            "paused": scene.isPaused,
            "title": titleText,
            "titleFont": titleFontName,
            "titleFontSize": Double(titleFontSize)
        ]
    }

    private func stopHTTPServer() {
        httpServer.stop()
        UserDefaults.standard.removeObject(forKey: kHTTPPort)
    }

    private var isTitleDynamic: Bool {
        titleText == "$time"
    }

    private var titleDisplayString: String {
        if isTitleDynamic {
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm:ss"
            return formatter.string(from: Date())
        }
        return titleText
    }

    private var titleAreaHeight: CGFloat {
        titleText.isEmpty ? 0 : titleFontSize + 8
    }

    private func setupWindow() {
        let windowWidth = CGFloat(LampConfig.gridWidth) * pixelScale
        let lampHeight = CGFloat(LampConfig.gridHeight) * pixelScale
        let windowHeight = lampHeight + titleAreaHeight

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
        let lampHeight = CGFloat(LampConfig.gridHeight) * pixelScale
        let sceneSize = CGSize(width: windowWidth, height: lampHeight)

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

        // Container view holds the SKView and title label
        let containerView = NSView(frame: NSRect(x: 0, y: 0, width: windowWidth, height: lampHeight + titleAreaHeight))

        let skView = SKView(frame: NSRect(x: 0, y: titleAreaHeight, width: windowWidth, height: lampHeight))
        skView.allowsTransparency = true
        skView.presentScene(scene)
        containerView.addSubview(skView)

        // Title label below the lamp
        titleLabel = NSTextField(labelWithString: titleDisplayString)
        titleLabel.frame = NSRect(x: 0, y: 0, width: windowWidth, height: titleAreaHeight)
        titleLabel.alignment = .center
        titleLabel.textColor = .white
        titleLabel.backgroundColor = .clear
        titleLabel.isBezeled = false
        titleLabel.isEditable = false
        titleLabel.font = NSFont(name: titleFontName, size: titleFontSize) ?? NSFont.systemFont(ofSize: titleFontSize)
        titleLabel.isHidden = titleText.isEmpty
        containerView.addSubview(titleLabel)

        window.contentView = containerView
        window.makeKeyAndOrderFront(nil)

        // Start timer if title is dynamic (e.g. "$time")
        configureTitleTimer()
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

        case "set-title":
            if let text = params.first(where: { $0.name == "text" })?.value {
                titleText = text
                UserDefaults.standard.set(text, forKey: kTitle)
                updateTitleDisplay()
            }

        case "set-title-font":
            if let font = params.first(where: { $0.name == "name" })?.value {
                titleFontName = font
                UserDefaults.standard.set(font, forKey: kTitleFont)
                updateTitleDisplay()
            }

        case "set-title-font-size":
            if let sizeStr = params.first(where: { $0.name == "value" })?.value,
               let size = Double(sizeStr) {
                titleFontSize = CGFloat(size)
                UserDefaults.standard.set(size, forKey: kTitleFontSize)
                updateTitleDisplay()
            }

        case "web":
            let port: UInt16
            if let portStr = params.first(where: { $0.name == "port" })?.value,
               let p = UInt16(portStr), p > 0 {
                port = p
            } else if httpServer.port > 0 {
                port = httpServer.port
            } else {
                port = 8080
            }
            if httpServer.port == 0 {
                startHTTPServer(port: port)
            }
            NSWorkspace.shared.open(URL(string: "http://localhost:\(port)/")!)

        case "http":
            if let portStr = params.first(where: { $0.name == "port" })?.value,
               let port = UInt16(portStr), port > 0 {
                startHTTPServer(port: port)
            } else if let action = params.first(where: { $0.name == "action" })?.value,
                      action == "stop" {
                stopHTTPServer()
            }

        case "quit":
            NSApplication.shared.terminate(nil)

        default:
            break
        }
    }

    private func updateTitleDisplay() {
        let oldTitleHeight = titleLabel.isHidden ? CGFloat(0) : titleLabel.frame.height
        let newTitleHeight = titleAreaHeight

        titleLabel.stringValue = titleDisplayString
        titleLabel.font = NSFont(name: titleFontName, size: titleFontSize) ?? NSFont.systemFont(ofSize: titleFontSize)
        titleLabel.isHidden = titleText.isEmpty

        // Manage the timer for dynamic titles
        configureTitleTimer()

        // Resize window and reposition views if title area height changed
        if oldTitleHeight != newTitleHeight {
            let windowWidth = window.frame.width
            let lampHeight = CGFloat(LampConfig.gridHeight) * pixelScale
            let newWindowHeight = lampHeight + newTitleHeight

            let newRect = NSRect(
                x: window.frame.origin.x,
                y: window.frame.origin.y + window.frame.height - newWindowHeight,
                width: windowWidth,
                height: newWindowHeight
            )
            window.setFrame(newRect, display: false)

            if let container = window.contentView {
                container.frame = NSRect(x: 0, y: 0, width: windowWidth, height: newWindowHeight)
                for subview in container.subviews {
                    if let skView = subview as? SKView {
                        skView.frame = NSRect(x: 0, y: newTitleHeight, width: windowWidth, height: lampHeight)
                    }
                }
            }

            titleLabel.frame = NSRect(x: 0, y: 0, width: windowWidth, height: newTitleHeight)
        }
    }

    private func configureTitleTimer() {
        titleTimer?.invalidate()
        titleTimer = nil

        if isTitleDynamic {
            titleTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
                guard let self = self else { return }
                self.titleLabel.stringValue = self.titleDisplayString
            }
        }
    }

    private func parseColor(from params: [URLQueryItem]) -> NSColor? {
        return LavaLampUtils.parseColor(from: params)
    }

    private func colorFromHex(_ hex: String) -> NSColor? {
        return LavaLampUtils.colorFromHex(hex)
    }

    private func parseSpeed(from params: [URLQueryItem]) -> CGFloat? {
        return LavaLampUtils.parseSpeed(from: params)
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
        let lampHeight = CGFloat(LampConfig.gridHeight) * scale
        let newHeight = lampHeight + titleAreaHeight

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
        let sceneSize = CGSize(width: newWidth, height: lampHeight)
        let oldColor = scene.lavaColor
        let oldSpeed = scene.speedMultiplier

        scene = LavaLampScene(size: sceneSize)
        scene.scaleMode = .aspectFill
        scene.backgroundColor = .clear
        scene.lavaColor = oldColor
        scene.speedMultiplier = oldSpeed

        if let container = window.contentView {
            container.frame = NSRect(x: 0, y: 0, width: newWidth, height: newHeight)
            for subview in container.subviews {
                if let skView = subview as? SKView {
                    skView.frame = NSRect(x: 0, y: titleAreaHeight, width: newWidth, height: lampHeight)
                    skView.presentScene(scene)
                }
            }
            titleLabel.frame = NSRect(x: 0, y: 0, width: newWidth, height: titleAreaHeight)
        }
    }
}
