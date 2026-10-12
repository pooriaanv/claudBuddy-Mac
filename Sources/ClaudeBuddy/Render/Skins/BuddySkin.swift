import BuddyCore
import SwiftUI

/// The original little guy: big round head, sprout curl, orange shirt.
struct BuddySkin: Skin {
    let rightShoulder = pt(136, 218)
    let reachLength: CGFloat = 50
    let tone = KnockTone.knuckle

    private let cream = Color(red: 1.0, green: 0.90, blue: 0.80)
    private let creamEdge = Color(red: 0.88, green: 0.70, blue: 0.56)
    private let orange = Color(red: 0.85, green: 0.47, blue: 0.34)
    private let orangeDark = Color(red: 0.66, green: 0.33, blue: 0.23)
    private let pants = Color(red: 0.26, green: 0.25, blue: 0.33)

    private var arm: Limb {
        Limb(fill: orange, edge: orangeDark, width: 16, handSize: 17, handFill: cream, handEdge: creamEdge, hand: .fist)
    }

    func draw(_ c: GraphicsContext, pose p: Pose) {
        // legs + shoes
        for (x, left) in [(88.0, true), (112.0, false)] {
            let up = p.footLift(left: left)
            c.fill(Path(roundedRect: CGRect(x: x - 8, y: 262 - up, width: 16, height: 22), cornerRadius: 7), pants)
            c.fill(ellipse(pt(x + (left ? -2 : 2), 285 - up), 24, 11), Palette.ink)
        }

        // body (breathing)
        var b = c
        b.translateBy(x: 100, y: 270)
        b.scaleBy(x: 1, y: p.breathe)
        b.translateBy(x: -100, y: -270)
        b.fill(Path(roundedRect: CGRect(x: 58, y: 206, width: 84, height: 64), cornerRadius: 30), orange, edge: orangeDark)
        b.fill(Paint.sparkle(pt(100, 240), 9, 3), cream)

        Paint.limb(c, arm, shoulder: pt(64, 218), angle: p.leftArm, length: 42)
        let reach = armLength(rest: 42, p)
        if !p.rightArmInFront {
            Paint.limb(c, arm, shoulder: rightShoulder, angle: p.rightArm, length: reach)
        }

        // head
        let h = Paint.head(c, p, pivot: pt(100, 205))
        let tx = CGFloat(p.turn) * 7
        for x in [28.0, 172.0] {
            h.fill(ellipse(pt(x - tx * 0.4, 150), 24, 26), cream, edge: creamEdge)
        }
        var curl = Path()
        curl.move(to: pt(100 + tx * 0.5, 74))
        curl.addCurve(to: pt(96, 50), control1: pt(98, 62), control2: pt(112, 52 - 4 * CGFloat(p.excitement)))
        curl.addCurve(to: pt(103, 58), control1: pt(88, 48), control2: pt(94, 62))
        h.line(curl, orange, 5)
        h.fill(ellipse(pt(100, 140), 148, 140), cream, edge: creamEdge, width: 2.2)

        Paint.blush(h, [pt(52 + tx, 166), pt(148 + tx, 166)], size: CGSize(width: 24, height: 12), pose: p)
        Paint.eyes(h, [pt(72 + tx, 142), pt(128 + tx, 142)], size: CGSize(width: 19, height: 25), pose: p)
        let browY: CGFloat = p.mood == .excited || p.mood == .surprised ? 110 : 120
        for x in [72.0, 128.0] {
            var brow = Path()
            brow.move(to: pt(x + tx - 8, browY + 2))
            brow.addQuadCurve(to: pt(x + tx + 8, browY + 2), control: pt(x + tx, browY - 4))
            h.line(brow, Palette.ink.opacity(0.8), 3)
        }
        Paint.mouth(h, at: pt(100 + tx, 168), pose: p)

        if p.rightArmInFront {
            Paint.limb(c, arm, shoulder: rightShoulder, angle: p.rightArm, length: reach, press: p.press)
        }
    }
}
