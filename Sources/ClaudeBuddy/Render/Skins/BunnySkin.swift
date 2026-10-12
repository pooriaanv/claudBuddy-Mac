import BuddyCore
import SwiftUI

/// A fluffy white bunny on four legs: long twitchy ears (they flop when sleepy), a cotton-ball tail,
/// little buck teeth — and it hops instead of walking.
struct BunnySkin: QuadrupedSkin {
    let tone = KnockTone.paw

    let fur = Color(red: 0.99, green: 0.97, blue: 0.95)
    let furEdge = Color(red: 0.80, green: 0.75, blue: 0.71)
    let farFur = Color(red: 0.93, green: 0.90, blue: 0.87)
    let paw = Color.white
    let pad = Color(red: 1.0, green: 0.66, blue: 0.74)
    let tailWidth: CGFloat = 18
    var tailTip: Color? { .white }
    let wagSpeed = 6.0
    let wagAmount = 2.0
    let hops = true

    private let pink = Color(red: 1.0, green: 0.70, blue: 0.77)

    /// Just a pom-pom: the "tail" is a short stub ending in a fluffy ball.
    func tailShape(_ posture: Posture) -> [CGPoint] {
        [pt(-4, -2), pt(-6, -4), pt(-8, -5)]
    }

    func frontTail(_ p: Pose) -> (path: Path, inFront: Bool) {
        var t = Path()
        t.move(to: pt(128, 270))
        t.addLine(to: pt(136, 268))
        return (t, false)
    }

    func drawMarkings(_ b: GraphicsContext, _ rig: QuadrupedRig) {
        b.fill(ellipse(pt(rig.hip.x + QuadrupedRig.bodyLength - 4, rig.hip.y + 10), 46, 34), .white)
    }

    func drawFrontMarkings(_ g: GraphicsContext) {
        g.fill(ellipse(pt(100, 246), 46, 54), .white)
    }

    func drawHead(_ h: GraphicsContext, _ p: Pose, tx: CGFloat) {
        let sleepy = p.mood == .sleepy ? 1.0 : 0.0
        let perk = p.excitement
        let twitch = earTwitch(p.t)
        drawEar(h, left: true, angle: -12 + perk * 6 - sleepy * 55 - twitch * 8)
        drawEar(h, left: false, angle: 12 - perk * 6 + sleepy * 55 + twitch * 3)

        h.fill(ellipse(pt(100, 148), 146, 126), fur, edge: furEdge, width: 2.6)
        // fluffy cheeks
        for x in [58.0, 142.0] { h.fill(ellipse(pt(x + tx * 0.5, 172), 44, 34), fur) }

        Paint.blush(h, [pt(56 + tx, 168), pt(144 + tx, 168)], size: CGSize(width: 22, height: 11), pose: p)
        Paint.eyes(h, [pt(72 + tx, 142), pt(128 + tx, 142)], size: CGSize(width: 21, height: 25), pose: p)

        let m = pt(100 + tx, 162)
        var nose = Path()
        nose.move(to: pt(m.x - 6, m.y - 3))
        nose.addLine(to: pt(m.x + 6, m.y - 3))
        nose.addLine(to: pt(m.x, m.y + 3))
        nose.closeSubpath()
        h.fill(nose, pad)
        h.line(nose, pad, 2.4)
        for side in [-1.0, 1.0] {
            for (dy, slope) in [(4.0, -4.0), (9.0, 3.0)] {
                var w = Path()
                w.move(to: pt(m.x + side * 22, m.y + dy))
                w.addLine(to: pt(m.x + side * 44, m.y + dy + slope))
                h.line(w, Palette.ink.opacity(0.3), 1.4)
            }
        }
        if p.mouth == .smile || p.mouth == .small {
            var w = Path()
            w.move(to: pt(m.x, m.y + 3))
            w.addLine(to: pt(m.x, m.y + 7))
            w.move(to: pt(m.x - 8, m.y + 7))
            w.addQuadCurve(to: pt(m.x, m.y + 7), control: pt(m.x - 4, m.y + 12))
            w.addQuadCurve(to: pt(m.x + 8, m.y + 7), control: pt(m.x + 4, m.y + 12))
            h.line(w, Palette.ink, 2.2)
            // buck teeth
            let teeth = Path(roundedRect: CGRect(x: m.x - 5, y: m.y + 10, width: 10, height: 8), cornerRadius: 2)
            h.fill(teeth, .white, edge: furEdge, width: 1.2)
            var gap = Path()
            gap.move(to: pt(m.x, m.y + 10))
            gap.addLine(to: pt(m.x, m.y + 18))
            h.line(gap, furEdge, 1)
        } else {
            Paint.mouth(h, at: pt(m.x, m.y + 10), pose: p, width: 14)
        }
    }

    private func earTwitch(_ t: Double) -> Double {
        let local = t.truncatingRemainder(dividingBy: 3.7)
        return local < 0.2 ? sin(local / 0.2 * .pi) : 0
    }

    private func drawEar(_ h: GraphicsContext, left: Bool, angle: Double) {
        let anchor = pt(left ? 80 : 120, 96)
        let g = h.rotated(angle, around: anchor)
        g.fill(ellipse(pt(anchor.x, anchor.y - 42), 34, 92), fur, edge: furEdge, width: 2.4)
        g.fill(ellipse(pt(anchor.x, anchor.y - 40), 15, 64), pink)
    }
}
