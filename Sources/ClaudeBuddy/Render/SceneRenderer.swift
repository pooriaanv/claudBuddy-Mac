import BuddyCore
import SwiftUI

/// Draws a `Scene` with a skin: shadow, body transforms, the character, then effects and the speech bubble.
enum SceneRenderer {
    /// Design canvas: the 200×300 character space plus margins for the bubble and the knocking hand.
    static let design = CGSize(width: 240, height: 320)

    static func draw(_ ctx: inout GraphicsContext, size: CGSize, scene: PetScene, skin: Skin) {
        let s = size.width / design.width
        ctx.scaleBy(x: s, y: s)
        ctx.translateBy(x: 20 + scene.shake.width, y: 20 + scene.shake.height)
        let p = scene.pose

        let shadowScale = max(0.4, 1 + p.lift / 80) * (0.6 + 0.4 * scene.shadow)
        ctx.fill(ellipse(pt(100, 288), 110 * shadowScale, 12 * shadowScale), .black.opacity(0.04 + 0.1 * scene.shadow))

        var body = ctx
        body.translateBy(x: 0, y: p.lift)
        if p.lean != 0 && skin.usesLean { body = body.rotated(p.lean, around: pt(100, 288)) }
        if p.swing != 0 { body = body.rotated(p.swing, around: pt(100, 70)) }
        skin.draw(body, pose: p)

        var fx = ctx
        fx.translateBy(x: 0, y: p.lift)
        let hit = skin.knockPoint(p)
        for age in scene.knockAges { glassMark(ctx, at: pt(hit.x, hit.y + p.lift), age: age, text: scene.knockText) }
        for (i, age) in scene.heartAges.enumerated() { hearts(fx, age: age, index: i) }
        if scene.sleeping { zzz(fx, t: p.t) }
        if scene.dancing { notes(fx, t: p.t) }
        if let bubble = scene.bubble { drawBubble(ctx, bubble) } else if let hint = scene.hint { drawHint(ctx, hint, t: p.t) }
    }

    /// A small floating tag above the head. Deliberately quiet: no motion beyond a slow float.
    static func drawHint(_ ctx: GraphicsContext, _ text: String, t: Double) {
        var g = ctx
        g.translateBy(x: 0, y: CGFloat(sin(t * 1.6)) * 1.5)
        let label = g.resolve(Text(text).font(.system(size: 15, weight: .semibold, design: .rounded))
            .foregroundColor(Palette.ink.opacity(0.85)))
        let size = label.measure(in: CGSize(width: 170, height: 22))
        let w = size.width + 22, h: CGFloat = 26
        let rect = CGRect(x: 100 - w / 2, y: 20 - h / 2, width: w, height: h)
        let pill = Path(roundedRect: rect, cornerRadius: h / 2)
        var shadow = g
        shadow.translateBy(x: 0, y: 1.5)
        shadow.fill(pill, .black.opacity(0.15))
        g.fill(pill, .white.opacity(0.92))
        g.stroke(pill, with: .color(Color(red: 0.36, green: 0.72, blue: 0.45).opacity(0.7)), lineWidth: 1.5)
        g.draw(label, in: CGRect(x: rect.minX + 11, y: rect.midY - size.height / 2, width: size.width, height: size.height))
    }

    static func glassMark(_ ctx: GraphicsContext, at p: CGPoint, age: Double, text: String) {
        let fog = max(0, 1 - age / 2.5)
        ctx.fill(ellipse(p, 46, 40), with: .radialGradient(
            Gradient(colors: [.white.opacity(0.45 * fog), .white.opacity(0)]), center: p, startRadius: 0, endRadius: 24))
        if age < 0.5 {
            let f = 1 - age / 0.5
            let r = 14 + age * 70
            ctx.stroke(circle(p, r * 2), with: .color(.white.opacity(0.75 * f)), lineWidth: 2.5)
            ctx.stroke(circle(p, r * 2 + 4), with: .color(Palette.ink.opacity(0.3 * f)), lineWidth: 1)
        }
        if age < 0.16 {
            for i in 0..<7 {
                let a = Double(i) / 7 * 2 * .pi + 0.3
                var l = Path()
                l.move(to: pt(p.x + cos(a) * 20, p.y + sin(a) * 20))
                l.addLine(to: pt(p.x + cos(a) * 30, p.y + sin(a) * 30))
                ctx.line(l, Palette.ink.opacity(0.8), 2.2)
            }
        }
        if age < 0.6 {
            var g = ctx
            g.opacity = 1 - age / 0.6
            g.draw(Text(text).font(.system(size: 13, weight: .black, design: .rounded))
                .foregroundColor(Color(red: 0.66, green: 0.33, blue: 0.23)),
                   at: pt(p.x + 14, p.y - 42 - age * 20))
        }
    }

    static func hearts(_ ctx: GraphicsContext, age: Double, index: Int) {
        for k in 0..<3 {
            let a = age - Double(k) * 0.12
            guard a > 0, a < 1.3 else { continue }
            let x = 100 + CGFloat([-30, 4, 34][k]) + CGFloat(sin(a * 6 + Double(k))) * 5
            let y = 70 - CGFloat(a) * 60 - CGFloat(index % 3) * 6
            var g = ctx
            g.opacity = min(1, (1.3 - a) / 0.4)
            let size = 14 * CGFloat(min(1, a / 0.15))
            g.fill(Paint.heart(pt(x, y), size), Palette.heart)
        }
    }

    static func zzz(_ ctx: GraphicsContext, t: Double) {
        for k in 0..<3 {
            let ph = (t * 0.45 + Double(k) / 3).truncatingRemainder(dividingBy: 1)
            var g = ctx
            g.opacity = sin(ph * .pi)
            g.draw(Text("z").font(.system(size: 10 + ph * 10, weight: .heavy, design: .rounded))
                .foregroundColor(Color(red: 0.42, green: 0.48, blue: 0.62)),
                   at: pt(150 + ph * 22, 78 - ph * 44))
        }
    }

    static func notes(_ ctx: GraphicsContext, t: Double) {
        for k in 0..<2 {
            let ph = (t * 0.7 + Double(k) / 2).truncatingRemainder(dividingBy: 1)
            var g = ctx
            g.opacity = sin(ph * .pi)
            let side: CGFloat = k == 0 ? -1 : 1
            g.draw(Text(k == 0 ? "♪" : "♫").font(.system(size: 16, weight: .bold))
                .foregroundColor(Color(red: 0.55, green: 0.42, blue: 0.85)),
                   at: pt(100 + side * (70 + ph * 10), 120 - ph * 50))
        }
    }

    static func drawBubble(_ ctx: GraphicsContext, _ b: Bubble) {
        let appear = b.appear
        guard appear > 0 else { return }
        var g = ctx
        let tail = pt(122, 60)
        g.translateBy(x: tail.x, y: tail.y)
        let pop = 0.6 + 0.4 * appear + sin(appear * .pi) * 0.08
        g.scaleBy(x: pop, y: pop)
        g.translateBy(x: -tail.x, y: -tail.y)
        g.opacity = appear

        let mark = b.rtl ? "\u{200F}" : ""
        let title = g.resolve(Text(mark + b.title)
            .font(.system(size: 13, weight: .heavy, design: .rounded)).foregroundColor(Palette.ink))
        let sub = g.resolve(Text(mark + b.subtitle)
            .font(.system(size: 9, weight: .medium, design: .rounded)).foregroundColor(Palette.ink.opacity(0.65)))
        let ts = title.measure(in: CGSize(width: 176, height: 40))
        let ss = sub.measure(in: CGSize(width: 176, height: 30))
        let w = min(196, max(ts.width, ss.width) + 24)
        let h = ts.height + ss.height + 18
        let rect = CGRect(x: 100 - w / 2, y: 50 - h, width: w, height: h)

        var bubble = Path(roundedRect: rect, cornerRadius: 16)
        bubble.move(to: pt(tail.x - 8, rect.maxY - 1))
        bubble.addLine(to: pt(tail.x + 4, tail.y))
        bubble.addLine(to: pt(tail.x + 6, rect.maxY - 1))
        var shadow = g
        shadow.translateBy(x: 0, y: 2.5)
        shadow.fill(bubble, .black.opacity(0.18))
        g.fill(bubble, .white)
        g.stroke(Path(roundedRect: rect, cornerRadius: 16), with: .color(Color(red: 0.85, green: 0.47, blue: 0.34).opacity(0.55)), lineWidth: 1.5)
        g.draw(title, in: CGRect(x: 100 - ts.width / 2, y: rect.minY + 8, width: ts.width, height: ts.height))
        g.draw(sub, in: CGRect(x: 100 - ss.width / 2, y: rect.minY + 10 + ts.height, width: ss.width, height: ss.height))
    }
}

/// Live model the pet window draws from.
final class SceneModel: ObservableObject {
    @Published var scene = PetScene()
    @Published var skin: SkinID = .buddy
}

struct SceneView: View {
    @ObservedObject var model: SceneModel

    var body: some View {
        let scene = model.scene
        let skin = SkinCatalog.skin(model.skin)
        // Synchronous: async rendering can present an empty frame while the window moves.
        Canvas { ctx, size in
            SceneRenderer.draw(&ctx, size: size, scene: scene, skin: skin)
        }
    }
}

/// Self-animating preview (settings window).
struct SkinPreview: View {
    let skin: SkinID
    var activity: Activity = .sit

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1.0 / 15)) { tl in
            Canvas { ctx, size in
                let t = tl.date.timeIntervalSinceReferenceDate
                var input = AnimationInput(t: t)
                input.activity = activity
                input.activityElapsed = t.truncatingRemainder(dividingBy: activity == .wave ? 4 : 3)
                if activity == .wave && input.activityElapsed > 1.8 { input.activity = .sit }
                SceneRenderer.draw(&ctx, size: size, scene: Animator.scene(input), skin: SkinCatalog.skin(skin))
            }
        }
    }
}
