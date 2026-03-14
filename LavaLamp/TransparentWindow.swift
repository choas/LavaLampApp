import AppKit

class TransparentWindow: NSWindow {
    private var initialMouseLocation: NSPoint = .zero
    private var initialWindowOrigin: NSPoint = .zero
    private var didDrag = false
    var onClicked: (() -> Void)?

    init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        isOpaque = false
        backgroundColor = .clear
        level = .floating
        hasShadow = false
        ignoresMouseEvents = false
        collectionBehavior = [.canJoinAllSpaces, .stationary]
        isMovableByWindowBackground = false
    }

    override var canBecomeKey: Bool { true }

    override func sendEvent(_ event: NSEvent) {
        switch event.type {
        case .leftMouseDown:
            initialMouseLocation = NSEvent.mouseLocation
            initialWindowOrigin = frame.origin
            didDrag = false
        case .leftMouseUp:
            if !didDrag {
                onClicked?()
            }
        case .leftMouseDragged:
            didDrag = true
            let currentLocation = NSEvent.mouseLocation
            let deltaX = currentLocation.x - initialMouseLocation.x
            let deltaY = currentLocation.y - initialMouseLocation.y
            setFrameOrigin(NSPoint(
                x: initialWindowOrigin.x + deltaX,
                y: initialWindowOrigin.y + deltaY
            ))
        default:
            super.sendEvent(event)
        }
    }
}
