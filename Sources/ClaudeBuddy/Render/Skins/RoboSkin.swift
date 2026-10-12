import BuddyCore
import SwiftUI

/// A tiny hovering robot with a face screen, glowing eyes and a blinking antenna.
struct RoboSkin: Skin {
    let rightShoulder = pt(136, 224)
    let reachLength: CGFloat = 44
    let tone = KnockTone.metal

    private let shell = Color(red: 0.94, green: 0.96, blue: 0.99)
    private let shellEdge = Color(red: 0.70, green: 0.76, blue: 0.85)
    private let metal = Color(red: 0.79, green: 0.83, blue: 0.89)
    private let screen = Color(red: 0.12, green: 0.15, blue: 0.22)
    private let glow = Color(red: 0.40, green: 0.95, blue: 0.89)
    private let coral = Color(red: 1.0, green: 0.54, blue: 0.40)
    private let pinkGlow = Color(red: 1.0, green: 0.49, blue: 0.71)

    private var arm: Limb {
        Limb(fill: metal, edge: shellEdge, width: 12, handSize: 16, handFill: shell, handEdge: shellEdge, hand: .robot)
    }

    func draw(_ c0: GraphicsContext, pose p: Pose) {
        let asleep = p.mood == .sleepy && p.eyeOpen < 0.35
        // hovering: bob gently above the floor
        var c = c0
        c.translateBy(x: 0, y: -6 + sin(p.t * 2.4) * 3)

        // thruster glow
        let thrust = 0.6 + 0.4 * sin(p.t * 30) * sin(p.t * 17) + (p.stepPhase != nil ? 0.4 : 0)
        c.fill(ellipse(pt(100, 280), 30 * thrust + 10, 12), glow.opacity(asleep ? 0.15 : 0.35))
        c.fill(ellipse(pt(100, 278), 16, 7), glow.opacity(asleep ? 0.3 : 0.9))
        c.fill(Path(roundedRect: CGRect(x: 86, y: 262, width: 28, height: 14), cornerRadius: 6), metal, edge: shellEdge)

        // body
        c.fill(Path(roundedRect: CGRect(x: 62, y: 210, width: 76, height: 58), cornerRadius: 24), shell, edge: shellEdge)
        c.fill(Path(roundedRect: CGRect(x: 83, y: 225, width: 34, height: 26), cornerRadius: 8), screen)
        let beat = asleep ? 0.3 : 0.75 + 0.25 * sin(p.t * 6)
        c.fill(Paint.heart(pt(100, 239), 16 * (0.9 + 0.1 * beat)), pinkGlow.opacity(beat))
        for x in [70.0, 130.0] { c.fill(circle(pt(x, 258), 4), shellEdge) }

        Paint.limb(c, arm, shoulder: pt(64, 224), angle: p.leftArm, length: 38)
        let reach = armLength(rest: 38, p)
        if !p.rightArmInFront {
            Paint.limb(c, arm, shoulder: rightShoulder, angle: p.rightArm, length: reach)
        }

        // head
        let h = Paint.head(c, p, pivot: pt(100, 208))
        let tx = CGFloat(p.turn) * 8
        // antenna
        h.line({ var a = Path(); a.move(to: pt(100, 86)); a.addLine(to: pt(100 + tx * 0.3, 62 - 4 * CGFloat(p.excitement))); return a }(), metal, 4)
        let blink = p.excitement > 0.5 ? (sin(p.t * 14) > 0 ? 1.0 : 0.35) : (asleep ? 0.25 : 0.7 + 0.3 * sin(p.t * 2))
        let tip = pt(100 + tx * 0.3, 56 - 4 * CGFloat(p.excitement))
        h.fill(circle(tip, 22), coral.opacity(0.25 * blink))
        h.fill(circle(tip, 14), coral.opacity(0.5 + 0.5 * blink), edge: Color(red: 0.85, green: 0.38, blue: 0.27), width: 1.5)
        // ear modules
        for x in [22.0, 178.0] {
            h.fill(Path(roundedRect: CGRect(x: x - 9, y: 124, width: 18, height: 42), cornerRadius: 8), metal, edge: shellEdge)
            h.fill(circle(pt(x, 145), 8), coral)
        }
        h.fill(Path(roundedRect: CGRect(x: 28, y: 84, width: 144, height: 118), cornerRadius: 40), shell, edge: shellEdge, width: 2.2)
        let face = Path(roundedRect: CGRect(x: 44, y: 101, width: 112, height: 80), cornerRadius: 28)
        h.fill(face, screen)
        h.fill(Path(roundedRect: CGRect(x: 54, y: 107, width: 40, height: 10), cornerRadius: 5), .white.opacity(0.07))

        var f = h
        f.clip(to: face)
        drawFace(f, p, tx: tx, asleep: asleep)

        if p.rightArmInFront {
            Paint.limb(c, arm, shoulder: rightShoulder, angle: p.rightArm, length: reach, press: p.press)
        }
    }

    private func drawFace(_ f: GraphicsContext, _ p: Pose, tx: CGFloat, asleep: Bool) {
        let eyeColor = asleep ? glow.opacity(0.4) : glow
        for x: CGFloat in [72, 128] {
            let c = pt(x + tx + p.look.x * 4, 136 + p.look.y * 3)
            switch p.mood {
            case .happy:
                var a = Path()
                a.move(to: pt(c.x - 10, c.y + 4))
                a.addLine(to: pt(c.x, c.y - 6))
                a.addLine(to: pt(c.x + 10, c.y + 4))
                f.line(a, eyeColor, 4.5)
            case .surprised:
                f.stroke(circle(c, 18), with: .color(eyeColor), lineWidth: 4)
            case _ where asleep:
                var a = Path()
                a.move(to: pt(c.x - 9, c.y + 2))
                a.addLine(to: pt(c.x + 9, c.y + 2))
                f.line(a, eyeColor, 4)
            default:
                let big: CGFloat = p.mood == .excited ? 1.2 : 1
                let w: CGFloat = 17 * big, h: CGFloat = max(3, 25 * big * CGFloat(p.eyeOpen))
                let eye = Path(roundedRect: CGRect(x: c.x - w / 2, y: c.y - h / 2, width: w, height: h), cornerRadius: min(w, h) / 2)
                f.fill(Path(roundedRect: CGRect(x: c.x - w / 2 - 4, y: c.y - h / 2 - 4, width: w + 8, height: h + 8), cornerRadius: (min(w, h) + 8) / 2), eyeColor.opacity(0.25))
                f.fill(eye, eyeColor)
                if p.eyeOpen > 0.5 { f.fill(circle(pt(c.x - w * 0.18, c.y - h * 0.22), w * 0.32), .white.opacity(0.85)) }
            }
        }
        for x in [58.0, 142.0] {
            f.fill(ellipse(pt(x + tx, 160), 16, 7), pinkGlow.opacity(p.mood == .happy || p.mood == .excited ? 0.8 : 0.5))
        }
        let m = pt(100 + tx, 163)
        switch p.mouth {
        case .grin:
            var d = Path()
            d.move(to: pt(m.x - 10, m.y - 3))
            d.addLine(to: pt(m.x + 10, m.y - 3))
            d.addQuadCurve(to: pt(m.x - 10, m.y - 3), control: pt(m.x, m.y + 14))
            d.closeSubpath()
            f.fill(d, glow)
        case .o:
            f.stroke(ellipse(pt(m.x, m.y + 2), 10, 8 + 6 * CGFloat(p.mouthOpen)), with: .color(glow), lineWidth: 3)
        case .smile, .small:
            var s = Path()
            let w: CGFloat = p.mouth == .small ? 6 : 10
            s.move(to: pt(m.x - w, m.y - 1))
            s.addQuadCurve(to: pt(m.x + w, m.y - 1), control: pt(m.x, m.y + 8))
            f.line(s, asleep ? glow.opacity(0.4) : glow, 3)
        }
    }
}
