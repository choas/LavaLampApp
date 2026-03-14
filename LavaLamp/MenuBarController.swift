import AppKit
import SwiftUI

class MenuBarController {
    private var statusItem: NSStatusItem!
    private var scene: LavaLampScene?

    var onColorChanged: ((NSColor) -> Void)?
    var onSpeedChanged: ((CGFloat) -> Void)?
    var onSizeChanged: ((LampSize) -> Void)?
    var onClickThroughChanged: ((Bool) -> Void)?

    enum LampSize: String, CaseIterable {
        case small = "Small"
        case medium = "Medium"
        case large = "Large"

        var scale: CGFloat {
            switch self {
            case .small: return 3.0
            case .medium: return 4.0
            case .large: return 5.0
            }
        }
    }

    func setup(scene: LavaLampScene) {
        self.scene = scene

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "flame.fill", accessibilityDescription: "Lava Lamp")
        }

        buildMenu()
    }

    private func buildMenu() {
        let menu = NSMenu()

        // Color submenu
        let colorItem = NSMenuItem(title: "Lava Color", action: nil, keyEquivalent: "")
        let colorSubmenu = NSMenu()

        let colors: [(String, NSColor)] = [
            ("Orange (Classic)", .orange),
            ("Red", .red),
            ("Blue", NSColor(red: 0.2, green: 0.4, blue: 1.0, alpha: 1.0)),
            ("Green", NSColor(red: 0.2, green: 0.8, blue: 0.3, alpha: 1.0)),
            ("Purple", NSColor(red: 0.6, green: 0.2, blue: 0.9, alpha: 1.0)),
            ("Pink", NSColor(red: 1.0, green: 0.3, blue: 0.5, alpha: 1.0)),
            ("Custom...", .clear),
        ]

        for (name, color) in colors {
            let item = NSMenuItem(title: name, action: #selector(colorSelected(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = color
            colorSubmenu.addItem(item)
        }

        colorItem.submenu = colorSubmenu
        menu.addItem(colorItem)

        // Speed submenu
        let speedItem = NSMenuItem(title: "Speed", action: nil, keyEquivalent: "")
        let speedSubmenu = NSMenu()
        let speeds: [(String, CGFloat)] = [
            ("Slow", 0.5),
            ("Normal", 1.0),
            ("Fast", 2.0),
        ]
        for (name, speed) in speeds {
            let item = NSMenuItem(title: name, action: #selector(speedSelected(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = speed
            if speed == 1.0 {
                item.state = .on
            }
            speedSubmenu.addItem(item)
        }
        speedItem.submenu = speedSubmenu
        menu.addItem(speedItem)

        // Size submenu
        let sizeItem = NSMenuItem(title: "Size", action: nil, keyEquivalent: "")
        let sizeSubmenu = NSMenu()
        for lampSize in LampSize.allCases {
            let item = NSMenuItem(title: lampSize.rawValue, action: #selector(sizeSelected(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = lampSize.rawValue
            if lampSize == .medium {
                item.state = .on
            }
            sizeSubmenu.addItem(item)
        }
        sizeItem.submenu = sizeSubmenu
        menu.addItem(sizeItem)

        menu.addItem(NSMenuItem.separator())

        // Click-through toggle
        let clickThrough = NSMenuItem(title: "Click-Through Mode", action: #selector(toggleClickThrough(_:)), keyEquivalent: "")
        clickThrough.target = self
        menu.addItem(clickThrough)

        menu.addItem(NSMenuItem.separator())

        // Quit
        let quitItem = NSMenuItem(title: "Quit Lava Lamp", action: #selector(quitApp(_:)), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    @objc private func colorSelected(_ sender: NSMenuItem) {
        guard let color = sender.representedObject as? NSColor else { return }

        if color == .clear {
            // Show color picker
            let colorPanel = NSColorPanel.shared
            colorPanel.setTarget(self)
            colorPanel.setAction(#selector(colorPanelChanged(_:)))
            colorPanel.orderFront(nil)
        } else {
            onColorChanged?(color)
            updateColorMenuState(sender)
        }
    }

    @objc private func colorPanelChanged(_ sender: NSColorPanel) {
        onColorChanged?(sender.color)
    }

    @objc private func speedSelected(_ sender: NSMenuItem) {
        guard let speed = sender.representedObject as? CGFloat else { return }
        onSpeedChanged?(speed)

        // Update checkmarks
        if let menu = sender.menu {
            for item in menu.items {
                item.state = .off
            }
        }
        sender.state = .on
    }

    @objc private func sizeSelected(_ sender: NSMenuItem) {
        guard let sizeRaw = sender.representedObject as? String,
              let size = LampSize(rawValue: sizeRaw) else { return }
        onSizeChanged?(size)

        if let menu = sender.menu {
            for item in menu.items {
                item.state = .off
            }
        }
        sender.state = .on
    }

    @objc private func toggleClickThrough(_ sender: NSMenuItem) {
        let isOn = sender.state == .on
        sender.state = isOn ? .off : .on
        onClickThroughChanged?(!isOn)
    }

    @objc private func quitApp(_ sender: NSMenuItem) {
        NSApp.terminate(nil)
    }

    private func updateColorMenuState(_ sender: NSMenuItem) {
        if let menu = sender.menu {
            for item in menu.items {
                item.state = .off
            }
        }
        sender.state = .on
    }
}
