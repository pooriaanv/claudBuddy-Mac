import BuddyCore
import SwiftUI

/// A fluffy white bunny on four legs: tufty fur, puffy cheeks, a forehead tuft, big sparkly eyes, long ears
/// (one tip folded over, both flop when sleepy), a cotton-ball tail, buck teeth — and it hops instead of walking.
struct BunnySkin: QuadrupedSkin {
    let tone = KnockTone.paw

    let fur = Color(red: 1.0, green: 0.98, blue: 0.96)
    let furEdge = Color(red: 0.84, green: 0.78, blue: 0.74)
    let farFur = Color(red: 0.94, green: 0.91, blue: 0.88)
    let paw = Color.white
    let pad = Color(red: 1.0, green: 0.66, blue: 0.74)
    let tailWidth: CGFloat = 4
    var tailTip: Color? { nil }
    let wagSpeed = 6.0
    let wagAmount = 1.0
    let hops = true

    private let pink = Color(red: 1.0, green: 0.72, blue: 0.79)

    /// Fur outline: an ellipse with little tufts all around it.
    private func fluffy(_ g: GraphicsContext, _ c: CGPoint, _ w: CGFloat, _ h: CGFloat,
                        tufts: Int, tuft: CGFloat, fill: Color, edge: Color, from: Double = 0, to: Double = 2 * .pi) {
        func shapes(grow: CGFloat) -> Path {
            var p = Path(ellipseIn: CGRect(x: c.x - w / 2 - grow, y: c.y - h / 2 - grow, width: w + grow * 2, height: h + grow * 2))
            for i in 0..<tufts {
                let a = from + (to - from) * Double(i) / Double(max(1, tufts - (to - from < 6.2 ? 1 : 0)))
                let q = pt(c.x + cos(a) * (w / 2 - tuft * 0.25), c.y + sin(a) * (h / 2 - tuft * 0.25))
                p.addEllipse(in: CGRect(x: q.x - tuft - grow, y: q.y - tuft - grow, width: (tuft + grow) * 2, height: (tuft + grow) * 2))
            }
            return p
        }
        g.fill(shapes(grow: 1.4), with: .color(edge))
        g.fill(shapes(grow: 0), with: .color(fill))
    }

    func tailShape(_ posture: Posture) -> [CGPoint] { [pt(-2, -1), pt(-3, -2), pt(-4, -2)] }

    func frontTail(_ p: Pose) -> (path: Path, inFront: Bool) {
        var t = Path()
        t.move(to: pt(132, 268)); t.addLine(to: pt(134, 267))
        return (t, false)
    }

    func drawMarkings(_ b: GraphicsContext, _ rig: QuadrupedRig) {
        let h = rig.hip
        // fluffy back and belly edges
        for i in 0..<7 {
            let x = h.x - 22 + CGFloat(i) * 18
            b.fill(circle(pt(x, h.y - 27), 16), fur)
            b.fill(circle(pt(x + 6, h.y + 26), 14), fur)
        }
        // cotton tail at the rump
        fluffy(b, pt(h.x - 30, h.y - 6), 26, 26, tufts: 8, tuft: 6, fill: .white, edge: furEdge)
        // fluffy white bib
        fluffy(b, pt(h.x + QuadrupedRig.bodyLength + 2, h.y + 6), 40, 40, tufts: 7, tuft: 6, fill: .white, edge: .white)
    }

    func drawFrontMarkings(_ g: GraphicsContext) {
        fluffy(g, pt(100, 244), 46, 52, tufts: 9, tuft: 6, fill: .white, edge: .white)
    }

    func drawHead(_ h: GraphicsContext, _ p: Pose, tx: CGFloat) {
        let sleepy = p.mood == .sleepy ? 1.0 : 0.0
        let perk = p.excitement
        let twitch = earTwitch(p.t)
        drawEar(h, left: true, angle: -14 + perk * 6 - sleepy * 55 - twitch * 8, folded: false)
        drawEar(h, left: false, angle: 14 - perk * 6 + sleepy * 55 + twitch * 3, folded: true)

        // fluffy round head + puffy cheeks
        fluffy(h, pt(100, 148), 150, 130, tufts: 22, tuft: 9, fill: fur, edge: furEdge)
        for x in [54.0, 146.0] {
            fluffy(h, pt(x + tx * 0.4, 176), 40, 30, tufts: 5, tuft: 7, fill: fur, edge: fur, from: 0.3, to: .pi - 0.3)
        }
        // forehead tuft
        for (dx, dy, r) in [(-8.0, 90.0, 9.0), (4.0, 86.0, 10.0), (14.0, 92.0, 7.0)] {
            h.fill(circle(pt(100 + dx + tx * 0.3, dy), r * 2 + 2.6), furEdge)
        }
        for (dx, dy, r) in [(-8.0, 90.0, 9.0), (4.0, 86.0, 10.0), (14.0, 92.0, 7.0)] {
            h.fill(circle(pt(100 + dx + tx * 0.3, dy), r * 2), fur)
        }
        h.fill(ellipse(pt(100, 104), 60, 22), fur)   // blend the tuft into the head

        // big sparkly eyes
        var eyePose = p
        if p.mood == .normal { eyePose.mood = .excited }
        Paint.blush(h, [pt(56 + tx, 170), pt(144 + tx, 170)], size: CGSize(width: 28, height: 14), pose: p)
        Paint.eyes(h, [pt(72 + tx, 143), pt(128 + tx, 143)], size: CGSize(width: 22, height: 26), pose: eyePose)
        if p.eyeOpen > 0.5 && (p.mood == .normal || p.mood == .excited) {
            for x in [72.0, 128.0] {
                h.fill(Paint.sparkle(pt(x + tx + 6, 133), 3.5, 1.2), .white)
            }
        }

        let m = pt(100 + tx, 163)
        var nose = Path()
        nose.move(to: pt(m.x - 5, m.y - 3)); nose.addLine(to: pt(m.x + 5, m.y - 3)); nose.addLine(to: pt(m.x, m.y + 2)); nose.closeSubpath()
        h.fill(nose, pad)
        h.line(nose, pad, 2.4)
        if p.mouth == .smile || p.mouth == .small {
            var w = Path()
            w.move(to: pt(m.x, m.y + 2)); w.addLine(to: pt(m.x, m.y + 6))
            w.move(to: pt(m.x - 7, m.y + 6))
            w.addQuadCurve(to: pt(m.x, m.y + 6), control: pt(m.x - 3.5, m.y + 10))
            w.addQuadCurve(to: pt(m.x + 7, m.y + 6), control: pt(m.x + 3.5, m.y + 10))
            h.line(w, Palette.ink, 2.1)
            let teeth = Path(roundedRect: CGRect(x: m.x - 4.5, y: m.y + 9, width: 9, height: 7), cornerRadius: 2)
            h.fill(teeth, .white, edge: furEdge, width: 1.1)
            var gap = Path(); gap.move(to: pt(m.x, m.y + 9)); gap.addLine(to: pt(m.x, m.y + 16))
            h.line(gap, furEdge, 1)
        } else {
            Paint.mouth(h, at: pt(m.x, m.y + 10), pose: p, width: 13)
        }
    }

    private func earTwitch(_ t: Double) -> Double {
        let local = t.truncatingRemainder(dividingBy: 3.7)
        return local < 0.2 ? sin(local / 0.2 * .pi) : 0
    }

    /// Long fluffy ear; the right one has its tip folded over.
    private func drawEar(_ h: GraphicsContext, left: Bool, angle: Double, folded: Bool) {
        let anchor = pt(left ? 78 : 122, 98)
        let g = h.rotated(angle, around: anchor)
        let length: CGFloat = folded ? 70 : 92
        fluffy(g, pt(anchor.x, anchor.y - length / 2 + 4), 36, length, tufts: 10, tuft: 5, fill: fur, edge: furEdge)
        g.fill(ellipse(pt(anchor.x, anchor.y - length / 2 + 6), 16, length - 28), pink)
        if folded {
            // the tip flopping forward
            let top = pt(anchor.x, anchor.y - length + 6)
            let f = g.rotated(left ? -60 : 60, around: top)
            fluffy(f, pt(top.x, top.y - 14), 30, 32, tufts: 6, tuft: 5, fill: fur, edge: furEdge)
            f.fill(ellipse(pt(top.x, top.y - 13), 13, 18), pink.opacity(0.8))
        }
    }
}
