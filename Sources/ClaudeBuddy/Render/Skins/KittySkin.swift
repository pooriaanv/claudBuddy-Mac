import BuddyCore
import SwiftUI

/// A ginger tabby kitten on four legs: white socks and chest, a long swishy tail,
/// and toe beans that squish on the glass when it rears up to knock.
struct KittySkin: QuadrupedSkin {
    let tone = KnockTone.paw

    let fur = Color(red: 0.96, green: 0.67, blue: 0.38)
    let furEdge = Color(red: 0.80, green: 0.48, blue: 0.22)
    let farFur = Color(red: 0.88, green: 0.58, blue: 0.30)
    let paw = Color(red: 1.0, green: 0.97, blue: 0.93)
    let pad = Color(red: 1.0, green: 0.62, blue: 0.69)
    let tailWidth: CGFloat = 13
    let tailTip: Color? = nil
    let wagSpeed = 2.2
    let wagAmount = 12.0
    let wrapsTail = true

    private let stripe = Color(red: 0.88, green: 0.53, blue: 0.25)
    private var white: Color { paw }

    func tailShape(_ posture: Posture) -> [CGPoint] {
        switch posture {
        case .stand: return [pt(-26, 0), pt(-38, -48), pt(-18, -80)]
        case .sit, .front: return [pt(-18, 34), pt(30, 44), pt(68, 34)]       // wrapped around the front paws
        case .rear: return [pt(-24, 20), pt(-34, 32), pt(-40, 30)]    // on the floor for balance
        case .stretch: return [pt(-20, -10), pt(-30, -60), pt(-10, -92)]
        case .lie: return [pt(-12, 30), pt(56, 42), pt(104, 30)]
        case .hang: return [pt(-6, 30), pt(10, 52), pt(0, 72)]
        }
    }

    /// Front view: tail curls around the front paws.
    func frontTail(_ p: Pose) -> (path: Path, inFront: Bool) {
        let flick = CGFloat(sin(p.t * 2.6)) * 5
        var t = Path()
        t.move(to: pt(132, 272))
        t.addCurve(to: pt(70 + flick, 284), control1: pt(170, 294), control2: pt(112, 298))
        return (t, true)
    }

    func drawFrontMarkings(_ g: GraphicsContext) {
        g.fill(ellipse(pt(100, 240), 46, 58), paw)   // white chest
        for (x, s) in [(64.0, 1.0), (136.0, -1.0)] {
            for k in 0..<2 {
                var st = Path()
                st.move(to: pt(x - s * 12, 250 + CGFloat(k) * 10))
                st.addLine(to: pt(x - s * 2, 254 + CGFloat(k) * 10))
                g.line(st, stripe, 4)
            }
        }
    }

    func drawMarkings(_ b: GraphicsContext, _ rig: QuadrupedRig) {
        let h = rig.hip
        for i in 0..<4 {
            let x = h.x - 6 + CGFloat(i) * 17
            var s = Path()
            s.move(to: pt(x, h.y - 29))
            s.addLine(to: pt(x + 3, h.y - 16))
            b.line(s, stripe, 5)
        }
        b.fill(ellipse(pt(h.x + QuadrupedRig.bodyLength + 6, h.y + 6), 40, 42), white)   // chest
    }

    func drawHead(_ h: GraphicsContext, _ p: Pose, tx: CGFloat) {
        let twitch = earTwitch(p.t) + p.excitement * -6
        drawEar(h, left: true, twitch: twitch)
        drawEar(h, left: false, twitch: -twitch * 0.6)
        h.fill(ellipse(pt(100, 146), 158, 128), fur, edge: furEdge, width: 2.6)
        for (x0, x1) in [(86.0, 89.0), (100.0, 100.0), (114.0, 111.0)] {
            var s = Path()
            s.move(to: pt(x0 + tx * 0.5, 87))
            s.addLine(to: pt(x1 + tx * 0.5, 101))
            h.line(s, stripe, 5)
        }
        for x in [26.0, 174.0] {
            var f = Path()
            f.move(to: pt(x, 150))
            f.addLine(to: pt(x + (x < 100 ? -9 : 9), 158))
            f.addLine(to: pt(x, 166))
            h.line(f, furEdge, 2)
        }

        Paint.blush(h, [pt(54 + tx, 168), pt(146 + tx, 168)], size: CGSize(width: 22, height: 11), pose: p)
        Paint.eyes(h, [pt(70 + tx, 140), pt(130 + tx, 140)], size: CGSize(width: 23, height: 27), pose: p)

        let m = pt(100 + tx, 168)
        h.fill(ellipse(pt(m.x - 10, m.y + 4), 30, 22), white)
        h.fill(ellipse(pt(m.x + 10, m.y + 4), 30, 22), white)
        var nose = Path()
        nose.move(to: pt(m.x - 6, m.y - 6))
        nose.addLine(to: pt(m.x + 6, m.y - 6))
        nose.addLine(to: pt(m.x, m.y))
        nose.closeSubpath()
        h.fill(nose, pad)
        h.line(nose, pad, 2)
        for side in [-1.0, 1.0] {
            for (dy, slope) in [(-2.0, -6.0), (4.0, 0.0), (10.0, 6.0)] {
                var w = Path()
                w.move(to: pt(m.x + side * 26, m.y + dy))
                w.addLine(to: pt(m.x + side * 52, m.y + dy + slope))
                h.line(w, Palette.ink.opacity(0.45), 1.6)
            }
        }
        if p.mouth == .smile || p.mouth == .small {
            var w = Path()   // the "ω" cat mouth
            w.move(to: pt(m.x - 9, m.y + 3))
            w.addQuadCurve(to: pt(m.x, m.y + 3), control: pt(m.x - 4.5, m.y + 9))
            w.addQuadCurve(to: pt(m.x + 9, m.y + 3), control: pt(m.x + 4.5, m.y + 9))
            h.line(w, Palette.ink, 2.4)
        } else {
            Paint.mouth(h, at: pt(m.x, m.y + 8), pose: p, width: 14)
        }
    }

    private func earTwitch(_ t: Double) -> Double {
        let local = t.truncatingRemainder(dividingBy: 5.3)
        return local < 0.25 ? sin(local / 0.25 * .pi) * 10 : 0
    }

    private func drawEar(_ h: GraphicsContext, left: Bool, twitch: Double) {
        let s: CGFloat = left ? 1 : -1
        let base = pt(100 - s * 48, 96)
        let g = h.rotated(twitch * Double(s), around: base)
        func x(_ v: CGFloat) -> CGFloat { 100 - s * (100 - v) }
        var outer = Path()
        outer.move(to: pt(x(30), 122))
        outer.addLine(to: pt(x(42), 58))
        outer.addLine(to: pt(x(88), 90))
        outer.closeSubpath()
        g.fill(outer, fur)
        g.stroke(outer, with: .color(furEdge), style: StrokeStyle(lineWidth: 2.6, lineJoin: .round))
        var inner = Path()
        inner.move(to: pt(x(44), 108))
        inner.addLine(to: pt(x(48), 74))
        inner.addLine(to: pt(x(74), 94))
        inner.closeSubpath()
        g.fill(inner, pad)
    }
}
