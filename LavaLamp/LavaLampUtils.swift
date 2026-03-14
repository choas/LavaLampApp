import AppKit

enum LavaLampUtils {

    static func colorFromHex(_ hex: String) -> NSColor? {
        var h = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if h.hasPrefix("#") { h.removeFirst() }
        guard h.count == 6, let val = UInt64(h, radix: 16) else { return nil }
        let r = CGFloat((val >> 16) & 0xFF) / 255.0
        let g = CGFloat((val >> 8) & 0xFF) / 255.0
        let b = CGFloat(val & 0xFF) / 255.0
        return NSColor(red: r, green: g, blue: b, alpha: 1.0)
    }

    static func parseColor(from params: [URLQueryItem]) -> NSColor? {
        if let hex = params.first(where: { $0.name == "hex" })?.value {
            return colorFromHex(hex)
        }
        if let rStr = params.first(where: { $0.name == "r" })?.value,
           let gStr = params.first(where: { $0.name == "g" })?.value,
           let bStr = params.first(where: { $0.name == "b" })?.value,
           let r = Double(rStr), let g = Double(gStr), let b = Double(bStr) {
            return NSColor(red: CGFloat(r), green: CGFloat(g), blue: CGFloat(b), alpha: 1.0)
        }
        return nil
    }

    static func parseSpeed(from params: [URLQueryItem]) -> CGFloat? {
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
}
