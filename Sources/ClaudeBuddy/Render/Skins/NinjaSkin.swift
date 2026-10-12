import BuddyCore
import SwiftUI

/// "Shadow" — a dark, menacing ninja: all-black mask with glowing slit eyes, crossed arms, tattered crimson scarf,
/// scratched-out headband plate (rogue ninja), shoulder armor, smoke at its feet, glowing katana when it dances.
/// `glow` picks the eye/blade color (red Ninja, cyan Cyber Ninja).
struct NinjaSkin: Skin {
    let rightShoulder = pt(136, 218)
    let reachLength: CGFloat = 50
    let tone = KnockTone.knuckle

    var glow = Color(red: 1.0, green: 0.18, blue: 0.24)

    private let suit = Color(red: 0.09, green: 0.10, blue: 0.13)
    private let suitEdge = Color(red: 0.02, green: 0.02, blue: 0.03)
    private let suitLight = Color(red: 0.20, green: 0.22, blue: 0.27)
    private let armor = Color(red: 0.16, green: 0.17, blue: 0.21)
    private let crimson = Color(red: 0.62, green: 0.06, blue: 0.14)
    private let crimsonDark = Color(red: 0.36, green: 0.03, blue: 0.08)
    private let steel = Color(red: 0.52, green: 0.56, blue: 0.62)
    private let glove = Color(red: 0.05, green: 0.05, blue: 0.07)

    private var arm: Limb {
        Limb(fill: suit, edge: suitEdge, width: 16, handSize: 17, handFill: glove, handEdge: suitEdge, hand: .fist)
    }

    func draw(_ c: GraphicsContext, pose p: Pose) {
        let swordOut = p.leftArm > 80 && p.mood != .sleepy
        let crossed = p.mood == .normal && p.stepPhase == nil && p.reach < 0.01 && !p.rightArmInFront
            && abs(p.leftArm - 14) < 14 && abs(p.rightArm + 14) < 14

        drawSmoke(c, p)
        drawScarf(c, p)

        // scabbard across the back
        var sheath = Path()
        sheath.move(to: pt(58, 276))
        sheath.addLine(to: pt(152, 194))
        c.line(sheath, suitEdge, 13)
        c.line(sheath, Color(red: 0.14, green: 0.12, blue: 0.13), 10)

        // legs, wrapped shins
        for (x, left) in [(88.0, true), (112.0, false)] {
            let up = p.footLift(left: left)
            c.fill(Path(roundedRect: CGRect(x: x - 9, y: 258 - up, width: 18, height: 26), cornerRadius: 7), suit, edge: suitEdge, width: 1.4)
            for k in 0..<2 {
                var wrap = Path()
                wrap.move(to: pt(x - 8, 266 - up + CGFloat(k) * 6))
                wrap.addLine(to: pt(x + 8, 263 - up + CGFloat(k) * 6))
                c.line(wrap, suitLight, 1.6)
            }
            c.fill(ellipse(pt(x + (left ? -2 : 2), 285 - up), 24, 10), glove)
        }

        // body
        var b = c
        b.translateBy(x: 100, y: 270)
        b.scaleBy(x: 1, y: p.breathe)
        b.translateBy(x: -100, y: -270)
        b.fill(Path(roundedRect: CGRect(x: 58, y: 206, width: 84, height: 64), cornerRadius: 26), suit, edge: suitEdge)
        var collar = Path()
        collar.move(to: pt(80, 208)); collar.addLine(to: pt(108, 244))
        collar.move(to: pt(120, 208)); collar.addLine(to: pt(100, 234))
        b.line(collar, suitLight, 3)
        b.fill(Path(roundedRect: CGRect(x: 60, y: 245, width: 80, height: 9), cornerRadius: 3), Color(red: 0.18, green: 0.18, blue: 0.21))
        for x in [74.0, 82.0] {   // kunai in the belt
            var k = Path()
            k.move(to: pt(x, 242)); k.addLine(to: pt(x - 2, 258))
            b.line(k, steel, 2.4)
        }

        if !swordOut { drawHandle(c) }

        if crossed {
            drawCrossedArms(c)
        } else {
            Paint.limb(c, arm, shoulder: pt(64, 218), angle: p.leftArm, length: 42)
            if swordOut { drawKatana(c, shoulder: pt(64, 218), angle: p.leftArm, armLength: 42, t: p.t) }
            if !p.rightArmInFront {
                Paint.limb(c, arm, shoulder: rightShoulder, angle: p.rightArm, length: armLength(rest: 42, p))
            }
        }
        drawShoulderArmor(c)

        drawHead(Paint.head(c, p, pivot: pt(100, 205)), p)

        if p.rightArmInFront {
            Paint.limb(c, arm, shoulder: rightShoulder, angle: p.rightArm, length: armLength(rest: 42, p), press: p.press)
        }
    }

    // MARK: head

    private func drawHead(_ h: GraphicsContext, _ p: Pose) {
        let tx = CGFloat(p.turn) * 6
        // hood with a swept-back point
        var hood = Path()
        hood.addEllipse(in: CGRect(x: 24, y: 70, width: 152, height: 142))
        var tip = Path()
        tip.move(to: pt(150, 84)); tip.addQuadCurve(to: pt(188, 74), control: pt(176, 70)); tip.addLine(to: pt(168, 104)); tip.closeSubpath()
        h.fill(tip, suit, edge: suitEdge, width: 2)
        h.fill(hood, suit, edge: suitEdge, width: 2.4)

        // headband: steel plate, 影 scratched through (rogue ninja)
        var clipped = h
        clipped.clip(to: hood)
        clipped.fill(Path(CGRect(x: 18, y: 94, width: 164, height: 14)), Color(red: 0.13, green: 0.13, blue: 0.16))
        let plate = CGRect(x: 80 + tx * 0.5, y: 90, width: 40, height: 22)
        h.fill(Path(roundedRect: plate, cornerRadius: 3), steel, edge: Color(red: 0.30, green: 0.32, blue: 0.37), width: 1.4)
        h.draw(Text("影").font(.system(size: 15, weight: .black)).foregroundColor(Color(red: 0.22, green: 0.24, blue: 0.29)),
               at: pt(plate.midX, plate.midY))
        var scratch = Path()
        scratch.move(to: pt(plate.minX + 3, plate.maxY - 4)); scratch.addLine(to: pt(plate.maxX - 3, plate.minY + 4))
        h.line(scratch, Color(red: 0.18, green: 0.19, blue: 0.23), 2.2)

        // mask: a slightly lighter band where the eyes are
        h.fill(Path(roundedRect: CGRect(x: 40 + tx, y: 124, width: 120, height: 38), cornerRadius: 19), Color(red: 0.03, green: 0.03, blue: 0.05))
        drawEyes(h, p, tx: tx)
    }

    /// Narrow, angled, glowing slits — they get brighter and pulse when it's on alert.
    // MARK: eyes

    private func eyeState(_ p: Pose) -> (open: CGFloat, strength: Double, alert: Bool) {
        let open: CGFloat
        switch p.mood {
        case .sleepy: open = max(0.15, CGFloat(p.eyeOpen))
        case .surprised: open = 1.3
        case .happy: open = 0.55
        default: open = max(0.12, CGFloat(p.eyeOpen))
        }
        let alert = p.mood == .excited
        let pulse = alert ? 0.8 + 0.2 * sin(p.t * 10) : 1
        return (open, (p.mood == .sleepy ? 0.4 : 1) * pulse, alert)
    }

    /// One thin, sharp glowing line per eye, slanting down toward the nose — an assassin's glare.
    /// Thicker and brighter on alert, thinner when smug (happy), dim when sleepy.
    private func drawEyes(_ h: GraphicsContext, _ p: Pose, tx: CGFloat) {
        let st = eyeState(p)
        for side in [-1.0, 1.0] {
            let s = CGFloat(side)
            let cx = 100 + s * 28 + tx + CGFloat(p.look.x) * 2.5, cy: CGFloat = 144
            var line = Path()
            line.move(to: pt(cx + s * 20, cy - 8))
            line.addLine(to: pt(cx - s * 14, cy + 3))
            let w = max(1.5, (st.alert ? 5 : 4) * st.open)
            var halo = h
            halo.addFilter(.blur(radius: st.alert ? 7 : 5))
            halo.line(line, glow.opacity(st.strength), w + 5)
            h.line(line, glow.opacity(st.strength), w + 1.5)
            h.line(line, .white.opacity(0.9 * st.strength), max(1, w * 0.45))
            h.fill(circle(pt(cx - s * 14, cy + 3), w + 2), with: .color(.white.opacity(0.8 * st.strength)))
        }
    }

    // MARK: body parts

    private func drawCrossedArms(_ c: GraphicsContext) {
        // forearms folded across the chest, gloved hands tucked at the elbows
        for (from, to) in [(pt(64, 222), pt(126, 236)), (pt(136, 222), pt(74, 238))] {
            var a = Path()
            a.move(to: from); a.addLine(to: to)
            c.line(a, suitEdge, 19)
            c.line(a, suit, 16)
            c.fill(circle(to, 15), glove, edge: suitEdge, width: 1.4)
        }
        var wrap = Path()
        wrap.move(to: pt(92, 226)); wrap.addLine(to: pt(98, 238))
        wrap.move(to: pt(104, 226)); wrap.addLine(to: pt(110, 236))
        c.line(wrap, suitLight, 1.6)
    }

    private func drawShoulderArmor(_ c: GraphicsContext) {
        for i in 0..<3 {
            let plate = Path(roundedRect: CGRect(x: 52 + CGFloat(i) * 2, y: 206 + CGFloat(i) * 8, width: 28 - CGFloat(i) * 3, height: 10), cornerRadius: 3)
            c.fill(plate, armor, edge: suitEdge, width: 1.2)
        }
    }

    private func drawScarf(_ c: GraphicsContext, _ p: Pose) {
        let speed = p.stepPhase != nil || p.excitement > 0.5 ? 9.0 : 2.6
        let knot = pt(128, 202)
        for (k, end, w) in [(0.0, pt(206, 176), 12.0), (1.7, pt(200, 214), 9.0)] {
            let wave = CGFloat(sin(p.t * speed + k)) * 8
            var tail = Path()
            tail.move(to: knot)
            tail.addCurve(to: pt(end.x, end.y + wave), control1: pt(152, knot.y - 10 + wave), control2: pt(180, end.y - wave))
            c.line(tail, crimsonDark, CGFloat(w) + 2.5)
            c.line(tail, crimson, CGFloat(w))
            // tattered end
            let e = pt(end.x, end.y + wave)
            for dy in [-4.0, 3.0] {
                var rag = Path()
                rag.move(to: e); rag.addLine(to: pt(e.x + 9, e.y + CGFloat(dy) + wave * 0.3))
                c.line(rag, crimson, 3)
            }
        }
        c.fill(Path(roundedRect: CGRect(x: 66, y: 196, width: 68, height: 14), cornerRadius: 7), crimson, edge: crimsonDark, width: 1.4)
    }

    /// Dark wisps drifting up around the feet.
    private func drawSmoke(_ c: GraphicsContext, _ p: Pose) {
        for k in 0..<5 {
            let ph = (p.t * 0.35 + Double(k) / 5).truncatingRemainder(dividingBy: 1)
            let x = 100 + CGFloat(sin(Double(k) * 2.1 + p.t * 0.5)) * 46
            var g = c
            g.opacity = sin(ph * .pi) * 0.35
            g.addFilter(.blur(radius: 4))
            g.fill(ellipse(pt(x, 284 - CGFloat(ph) * 40), 26 + CGFloat(ph) * 14, 14 + CGFloat(ph) * 8), with: .color(.black))
        }
    }

    private func drawHandle(_ c: GraphicsContext) {
        c.fill(Path(roundedRect: CGRect(x: 145, y: 189, width: 14, height: 14), cornerRadius: 2), Color(red: 0.25, green: 0.26, blue: 0.30))
        var grip = Path()
        grip.move(to: pt(154, 191)); grip.addLine(to: pt(174, 170))
        c.line(grip, glove, 8)
        for i in 0..<3 {
            let q = pt(158 + CGFloat(i) * 5.5, 186 - CGFloat(i) * 6)
            c.fill(Path(roundedRect: CGRect(x: q.x - 1.6, y: q.y - 1.6, width: 3.2, height: 3.2), cornerRadius: 0.5), crimson)
        }
    }

    /// Drawn katana with a glowing edge.
    private func drawKatana(_ c: GraphicsContext, shoulder: CGPoint, angle: Double, armLength: CGFloat, t: Double) {
        let hand = Paint.armEnd(shoulder: shoulder, angle: angle, length: armLength)
        let dx = (hand.x - shoulder.x) / armLength, dy = (hand.y - shoulder.y) / armLength
        func along(_ d: CGFloat) -> CGPoint { pt(hand.x + dx * d, hand.y + dy * d) }
        var grip = Path()
        grip.move(to: along(-8)); grip.addLine(to: along(10))
        c.line(grip, glove, 7)
        c.fill(Path(roundedRect: CGRect(x: along(11).x - 7, y: along(11).y - 7, width: 14, height: 14), cornerRadius: 2), Color(red: 0.25, green: 0.26, blue: 0.30))
        var blade = Path()
        blade.move(to: along(13))
        blade.addQuadCurve(to: along(82), control: pt(along(48).x - dy * 4, along(48).y + dx * 4))
        var halo = c
        halo.addFilter(.blur(radius: 6))
        halo.line(blade, glow.opacity(0.8 + 0.2 * sin(t * 12)), 9)
        c.line(blade, Color(red: 0.75, green: 0.78, blue: 0.84), 4.5)
        c.line(blade, .white, 1.6)
        c.fill(circle(hand, 17), glove, edge: suitEdge, width: 1.6)
    }
}
