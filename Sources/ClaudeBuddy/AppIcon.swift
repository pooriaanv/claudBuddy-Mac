import AppKit
import BuddyCore
import SwiftUI

/// The app icon (a kitten peeking over the edge) and the menu-bar face, drawn with the same skins as the pet.
enum AppIcon {
    // MARK: app icon

    /// Draws the icon in a 1024×1024 space (Apple's grid: an 824pt rounded square in the middle).
    static func drawIcon(_ ctx: inout GraphicsContext, size: CGFloat) {
        ctx.scaleBy(x: size / 1024, y: size / 1024)
        let tile = Path(roundedRect: CGRect(x: 100, y: 100, width: 824, height: 824), cornerRadius: 185)

        var shadow = ctx
        shadow.addFilter(.shadow(color: .black.opacity(0.28), radius: 18, x: 0, y: 12))
        shadow.fill(tile, with: .color(.white))

        ctx.fill(tile, with: .linearGradient(
            Gradient(colors: [Color(red: 1.0, green: 0.90, blue: 0.78), Color(red: 1.0, green: 0.72, blue: 0.66)]),
            startPoint: CGPoint(x: 512, y: 100), endPoint: CGPoint(x: 512, y: 924)))

        var inside = ctx
        inside.clip(to: tile)
        // soft sparkles
        for (x, y, r) in [(230.0, 250.0, 26.0), (800.0, 300.0, 18.0), (790.0, 640.0, 14.0), (210.0, 610.0, 12.0)] {
            inside.fill(Paint.sparkle(pt(x, y), r, r * 0.35), .white.opacity(0.75))
        }

        var pose = Pose()
        pose.mouth = .smile
        pose.look = CGPoint(x: 0, y: -0.15)
        let kitty = KittySkin()
        var head = inside
        head.translateBy(x: 512, y: 600)
        head.scaleBy(x: 3.7, y: 3.7)
        head.translateBy(x: -100, y: -146)
        kitty.drawHead(head, pose, tx: 0)

        // a window ledge to peek over, with paws hooked on it
        let ledge = Path(CGRect(x: 100, y: 790, width: 824, height: 140))
        inside.fill(ledge, with: .linearGradient(
            Gradient(colors: [Color(red: 1.0, green: 0.98, blue: 0.95), Color(red: 0.98, green: 0.90, blue: 0.86)]),
            startPoint: CGPoint(x: 512, y: 790), endPoint: CGPoint(x: 512, y: 924)))
        var edge = Path()
        edge.move(to: pt(100, 790))
        edge.addLine(to: pt(924, 790))
        inside.stroke(edge, with: .color(Color(red: 0.93, green: 0.72, blue: 0.62)), lineWidth: 6)
        for x: CGFloat in [370, 654] {
            var p = inside
            p.translateBy(x: x, y: 792)
            p.scaleBy(x: 3.7, y: 3.7)
            p.fill(ellipse(.zero, 34, 26), kitty.paw, edge: kitty.furEdge, width: 1.6)
            for dx: CGFloat in [-6, 6] {
                var toe = Path()
                toe.move(to: pt(dx, -12))
                toe.addLine(to: pt(dx, -5))
                p.line(toe, kitty.furEdge, 1.6)
            }
        }
        ctx.stroke(tile, with: .color(.white.opacity(0.35)), lineWidth: 4)
    }

    /// Writes an .iconset folder (for `iconutil -c icns`).
    static func writeIconset(to dir: URL) throws {
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        for base in [16, 32, 128, 256, 512] {
            for scale in [1, 2] {
                let px = CGFloat(base * scale)
                let name = scale == 1 ? "icon_\(base)x\(base).png" : "icon_\(base)x\(base)@2x.png"
                let view = Canvas { ctx, _ in drawIcon(&ctx, size: px) }.frame(width: px, height: px)
                try png(view, scale: 1).write(to: dir.appendingPathComponent(name))
            }
        }
    }

    // MARK: menu bar

    /// The selected character's face, 18pt, for the status item.
    static func menuBarImage(_ skinID: SkinID, badge: Bool = false) -> NSImage {
        var pose = Pose()
        pose.posture = .front          // four-legged skins: front view, head centered
        pose.mood = .normal
        let skin = SkinCatalog.skin(skinID)
        let view = Canvas { ctx, size in
            let crop: CGFloat = 150
            ctx.scaleBy(x: size.width / crop, y: size.width / crop)
            ctx.translateBy(x: -(100 - crop / 2), y: -(146 - crop / 2))
            skin.draw(ctx, pose: pose)
            if badge {
                // red "someone's waiting" dot, top-right (undo the crop transform)
                var dot = ctx
                dot.translateBy(x: 100 - crop / 2, y: 146 - crop / 2)
                let r = crop * 0.17
                let c = pt(crop - r * 1.05, r * 1.05)
                dot.fill(circle(c, r * 2 + crop * 0.05), with: .color(.white))
                dot.fill(circle(c, r * 2), with: .color(Color(red: 1.0, green: 0.27, blue: 0.27)))
            }
        }
        .frame(width: 18, height: 18)
        let cg = MainActor.assumeIsolated { () -> CGImage? in
            let r = ImageRenderer(content: view)
            r.scale = 2
            return r.cgImage
        }
        guard let cg else { return NSImage() }
        return NSImage(cgImage: cg, size: NSSize(width: 18, height: 18))
    }

    private static func png<V: View>(_ view: V, scale: CGFloat) throws -> Data {
        try MainActor.assumeIsolated {
            let r = ImageRenderer(content: view)
            r.scale = scale
            guard let cg = r.cgImage, let data = NSBitmapImageRep(cgImage: cg).representation(using: .png, properties: [:]) else {
                throw CocoaError(.fileWriteUnknown)
            }
            return data
        }
    }
}
