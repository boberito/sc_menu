//
//  IconColor.swift
//  SC Menu
//
//  Optional menu bar icon colours, set by profile (issue #27).
//  Keys in com.ttinc.sc-menu:
//    icon_color_inserted  String "#RRGGBB"  colour while a card is inserted
//    icon_color_removed   String "#RRGGBB"  colour while no card is inserted
//  Key absent or unreadable: the bundled icon is shown unchanged.
//

import AppKit

enum IconColor {
    static let insertedKey = "icon_color_inserted"
    static let removedKey = "icon_color_removed"

    /// The bundled icon at `fileURLString`, tinted when a colour is set for its state.
    /// The state is read from the asset name ("smartcard_in…" or "smartcard_out…").
    static func image(forFile fileURLString: String) -> NSImage? {
        guard let image = NSImage(byReferencingFile: fileURLString) else { return nil }
        let name = (fileURLString as NSString).lastPathComponent
        let key = name.hasPrefix("smartcard_in") ? insertedKey : removedKey
        guard let color = color(forKey: key) else { return image }
        return image.tinted(color)
    }

    /// "#RRGGBB" or "RRGGBB" from UserDefaults (managed or local); nil when absent or unreadable.
    static func color(forKey key: String) -> NSColor? {
        guard var hex = UserDefaults.standard.string(forKey: key)?
            .trimmingCharacters(in: .whitespacesAndNewlines) else { return nil }
        if hex.hasPrefix("#") { hex.removeFirst() }
        guard hex.count == 6, let value = UInt32(hex, radix: 16) else { return nil }
        return NSColor(srgbRed: CGFloat((value >> 16) & 0xFF) / 255,
                       green: CGFloat((value >> 8) & 0xFF) / 255,
                       blue: CGFloat(value & 0xFF) / 255,
                       alpha: 1)
    }
}

extension NSImage {
    /// A copy filled with `color` wherever this image is opaque. Not a template image,
    /// so the menu bar does not re-tint it for light or dark appearance.
    func tinted(_ color: NSColor) -> NSImage {
        let result = NSImage(size: size, flipped: false) { rect in
            self.draw(in: rect)
            color.set()
            rect.fill(using: .sourceAtop)
            return true
        }
        result.isTemplate = false
        return result
    }
}
