import CoreGraphics

enum LampConfig {
    static let gridWidth = 48
    static let gridHeight = 120
    static let defaultPixelScale: CGFloat = 2.0
    static let defaultBlobCount = 5

    // Glass shape
    static let glassTop = 12
    static let glassBottom = 110
    static let glassInset: CGFloat = 8
    static let glassMaxHalfWidth: CGFloat = CGFloat(gridWidth) / 2 - glassInset // 16

    // Cap and base
    static let capTop = 6
    static let capBottom = 12
    static let baseTop = 110
    static let baseBottom = 118

    static func glassHalfWidth(atRow y: CGFloat) -> CGFloat {
        let center = CGFloat(glassTop + glassBottom) / 2
        let halfHeight = CGFloat(glassBottom - glassTop) / 2
        let normalizedDist = abs(y - center) / halfHeight
        let taper = max(0, 1.0 - 0.3 * normalizedDist * normalizedDist)
        return glassMaxHalfWidth * taper
    }
}
