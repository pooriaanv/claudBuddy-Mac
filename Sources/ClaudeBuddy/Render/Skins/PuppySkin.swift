import BuddyCore
import SwiftUI

/// A cream puppy on four legs: floppy brown ears, a brown back patch, red collar and a curly, waggy tail.
struct PuppySkin: QuadrupedSkin {
    let tone = KnockTone.paw

    let fur = Color(red: 1.0, green: 0.95, blue: 0.87)
    let furEdge = Color(red: 0.85, green: 0.72, blue: 0.56)
    let farFur = Color(red: 0.94, green: 0.87, blue: 0.77)
    let paw = Color(red: 1.0, green: 0.95, blue: 0.87)
    let pad = Color(red: 0.86, green: 0.50, blue: 0.56)
    let tailWidth: CGFloat = 12
    var tailTip: Color? { ear }
    let wagSpeed = 9.0
    let wagAmount = 14.0

    private let ear = Color(red: 0.60, green: 0.39, blue: 0.25)
    private let earEdge = Color(red: 0.47, green: 0.29, blue: 0.18)
    private let patch = Color(red: 0.92, green: 0.73, blue: 0.54)
    private let collar = Color(red: 0.90, green: 0.28, blue: 0.30)
    private let gold = Color(red: 0.96, green: 0.77, blue: 0.27)

    func tailShape(_ posture: Posture) -> [CGPoint] {
        switch posture {
        case .stand: return [pt(-16, -12), pt(-30, -40), pt(-12, -46)]   // curled up
        case .sit, .front: return [pt(-16, 20), pt(-30, 30), pt(-42, 28)]        // sweeping the floor
        case .rear: return [pt(-16, 18), pt(-28, 28), pt(-38, 26)]
        case .stretch: return [pt(-14, -16), pt(-26, -48), pt(-8, -54)]
        case .lie: return [pt(-10, 24), pt(30, 36), pt(56, 28)]
        case .hang: return [pt(-4, 20), pt(6, 34), pt(0, 44)]
        }
    }

    /// Front view: tail peeks out at the side, wagging.
    func frontTail(_ p: Pose) -> (path: Path, inFront: Bool) {
        let wag = CGFloat(sin(p.t * wagSpeed * p.wag)) * 14
        var t = Path()
        t.move(to: pt(128, 262))
        t.addCurve(to: pt(158 + wag, 222), control1: pt(150, 262), control2: pt(166 + wag * 0.6, 240))
        return (t, false)
    }

    func drawFrontMarkings(_ g: GraphicsContext) {
        g.fill(ellipse(pt(100, 244), 44, 54), Color.white.opacity(0.7))
        g.fill(ellipse(pt(128, 228), 22, 20), patch)
    }

    func drawFrontNeck(_ g: GraphicsContext) {
        g.fill(Path(roundedRect: CGRect(x: 70, y: 200, width: 60, height: 11), cornerRadius: 5.5), collar)
        g.fill(circle(pt(100, 216), 12), gold, edge: Color(red: 0.8, green: 0.6, blue: 0.15), width: 1.5)
    }

    func drawMarkings(_ b: GraphicsContext, _ rig: QuadrupedRig) {
        let h = rig.hip
        b.fill(ellipse(pt(h.x + 22, h.y - 14), 50, 30), patch)
        b.fill(ellipse(pt(h.x - 14, h.y - 10), 22, 20), patch)
    }

    func drawNeck(_ g: GraphicsContext, _ rig: QuadrupedRig) {
        let c = rig.headCenter
        let band = Path(roundedRect: CGRect(x: c.x - 34, y: c.y + 36, width: 52, height: 11), cornerRadius: 5.5)
        g.fill(band, collar)
        g.fill(circle(pt(c.x - 8, c.y + 52), 11), gold, edge: Color(red: 0.8, green: 0.6, blue: 0.15), width: 1.5)
    }

    func drawHead(_ h: GraphicsContext, _ p: Pose, tx: CGFloat) {
        h.fill(ellipse(pt(100, 145), 152, 132), fur, edge: furEdge, width: 2.6)
        h.fill(ellipse(pt(131 + tx, 137), 42, 38), patch)
        for x in [74.0, 126.0] {
            h.fill(ellipse(pt(x + tx, 116), 11, 7), patch)   // eyebrow dots
        }

        let flop = -p.headTilt * 0.6 - p.excitement * 14 + sin(p.stepPhase ?? 0) * 8
        drawEar(h, left: true, angle: flop)
        drawEar(h, left: false, angle: -flop)

        Paint.blush(h, [pt(54 + tx, 168), pt(146 + tx, 168)], size: CGSize(width: 22, height: 11), pose: p)
        Paint.eyes(h, [pt(72 + tx, 140), pt(128 + tx, 140)], size: CGSize(width: 20, height: 24), pose: p)

        let m = pt(100 + tx, 170)
        h.fill(ellipse(m, 60, 40), .white)
        h.fill(ellipse(pt(m.x, m.y - 9), 21, 14), Palette.ink)
        h.fill(ellipse(pt(m.x - 4, m.y - 12), 6, 3.5), .white.opacity(0.8))
        var philtrum = Path()
        philtrum.move(to: pt(m.x, m.y - 3))
        philtrum.addLine(to: pt(m.x, m.y + 3))
        h.line(philtrum, Palette.ink, 2.2)
        if p.mouth == .o {
            Paint.mouth(h, at: pt(m.x, m.y + 6), pose: p, width: 14)
        } else {
            var smile = Path()
            smile.move(to: pt(m.x - 11, m.y + 2))
            smile.addQuadCurve(to: pt(m.x, m.y + 3), control: pt(m.x - 6, m.y + 9))
            smile.addQuadCurve(to: pt(m.x + 11, m.y + 2), control: pt(m.x + 6, m.y + 9))
            h.line(smile, Palette.ink, 2.4)
        }
        if p.mouth == .grin || p.stepPhase != nil {
            // panting
            let wiggle = sin(p.t * 12) * 1.5
            let tongueEdge = Color(red: 0.85, green: 0.38, blue: 0.45)
            h.fill(Path(roundedRect: CGRect(x: m.x - 7, y: m.y + 5 + wiggle, width: 14, height: 15), cornerRadius: 7),
                   Palette.blush, edge: tongueEdge, width: 1.4)
            var mid = Path()
            mid.move(to: pt(m.x, m.y + 8 + wiggle))
            mid.addLine(to: pt(m.x, m.y + 15 + wiggle))
            h.line(mid, tongueEdge, 1.4)
        }
    }

    private func drawEar(_ h: GraphicsContext, left: Bool, angle: Double) {
        let s: CGFloat = left ? 1 : -1
        func x(_ v: CGFloat) -> CGFloat { 100 - s * (100 - v) }
        let g = h.rotated(angle * Double(s), around: pt(x(46), 98))
        var e = Path()
        e.move(to: pt(x(48), 92))
        e.addCurve(to: pt(x(16), 168), control1: pt(x(24), 98), control2: pt(x(6), 146))
        e.addCurve(to: pt(x(52), 152), control1: pt(x(26), 186), control2: pt(x(50), 176))
        e.addCurve(to: pt(x(48), 92), control1: pt(x(56), 128), control2: pt(x(58), 104))
        e.closeSubpath()
        g.fill(e, ear, edge: earEdge, width: 2)
    }
}
