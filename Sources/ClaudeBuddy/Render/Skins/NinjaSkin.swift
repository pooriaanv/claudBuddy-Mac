import BuddyCore
import SwiftUI

/// A tiny ninja: navy hood with a face opening, a red headband whose tails flutter, and a katana on its back
/// that it draws and swings when it dances.
struct NinjaSkin: Skin {
    let rightShoulder = pt(136, 218)
    let reachLength: CGFloat = 50
    let tone = KnockTone.knuckle

    private let suit = Color(red: 0.20, green: 0.22, blue: 0.32)
    private let suitEdge = Color(red: 0.11, green: 0.12, blue: 0.19)
    private let suitLight = Color(red: 0.29, green: 0.32, blue: 0.45)
    private let skin = Color(red: 1.0, green: 0.89, blue: 0.79)
    private let skinEdge = Color(red: 0.88, green: 0.70, blue: 0.56)
    private let red = Color(red: 0.90, green: 0.26, blue: 0.28)
    private let glove = Color(red: 0.26, green: 0.28, blue: 0.38)
    private let steel = Color(red: 0.86, green: 0.89, blue: 0.93)
    private let gold = Color(red: 0.85, green: 0.64, blue: 0.25)
    private let scabbard = Color(red: 0.30, green: 0.18, blue: 0.17)

    private var arm: Limb {
        Limb(fill: suit, edge: suitEdge, width: 16, handSize: 17, handFill: glove, handEdge: suitEdge, hand: .fist)
    }

    func draw(_ c: GraphicsContext, pose p: Pose) {
        let swordOut = p.leftArm > 80 && p.mood != .sleepy

        // scabbard across the back
        var sheath = Path()
        sheath.move(to: pt(60, 274))
        sheath.addLine(to: pt(150, 196))
        c.line(sheath, suitEdge, 13)
        c.line(sheath, scabbard, 10)

        // legs + tabi
        for (x, left) in [(88.0, true), (112.0, false)] {
            let up = p.footLift(left: left)
            c.fill(Path(roundedRect: CGRect(x: x - 8, y: 260 - up, width: 16, height: 24), cornerRadius: 7), suit)
            c.fill(ellipse(pt(x + (left ? -2 : 2), 285 - up), 24, 11), Palette.ink)
        }

        // body
        var b = c
        b.translateBy(x: 100, y: 270)
        b.scaleBy(x: 1, y: p.breathe)
        b.translateBy(x: -100, y: -270)
        b.fill(Path(roundedRect: CGRect(x: 58, y: 206, width: 84, height: 64), cornerRadius: 30), suit, edge: suitEdge)
        var collar = Path()
        collar.move(to: pt(84, 208))
        collar.addLine(to: pt(100, 232))
        collar.addLine(to: pt(116, 208))
        b.line(collar, suitLight, 4)
        b.fill(Path(roundedRect: CGRect(x: 60, y: 244, width: 80, height: 10), cornerRadius: 4), red)
        b.fill(Path(roundedRect: CGRect(x: 108, y: 242, width: 10, height: 14), cornerRadius: 3), Color(red: 0.72, green: 0.18, blue: 0.20))

        // sword handle over the shoulder (only while sheathed)
        if !swordOut { drawHandle(c) }

        Paint.limb(c, arm, shoulder: pt(64, 218), angle: p.leftArm, length: 42)
        if swordOut { drawKatana(c, shoulder: pt(64, 218), angle: p.leftArm, armLength: 42) }
        let reach = armLength(rest: 42, p)
        if !p.rightArmInFront {
            Paint.limb(c, arm, shoulder: rightShoulder, angle: p.rightArm, length: reach)
        }

        drawHead(Paint.head(c, p, pivot: pt(100, 205)), p)

        if p.rightArmInFront {
            Paint.limb(c, arm, shoulder: rightShoulder, angle: p.rightArm, length: reach, press: p.press)
        }
    }

    private func drawHead(_ h: GraphicsContext, _ p: Pose) {
        let tx = CGFloat(p.turn) * 7
        let hood = ellipse(pt(100, 140), 148, 140)
        h.fill(hood, suit, edge: suitEdge, width: 2.4)

        // face opening
        let band = Path(roundedRect: CGRect(x: 44 + tx, y: 116, width: 112, height: 50), cornerRadius: 24)
        h.fill(band, skin, edge: skinEdge, width: 1.6)
        Paint.blush(h, [pt(58 + tx, 156), pt(142 + tx, 156)], size: CGSize(width: 18, height: 8), pose: p)
        Paint.eyes(h, [pt(74 + tx, 141), pt(126 + tx, 141)], size: CGSize(width: 18, height: 22), pose: p)
        // determined little brows
        if p.mood == .normal || p.mood == .excited {
            for (x0, x1, y0, y1) in [(62.0, 84.0, 123.0, 128.0), (138.0, 116.0, 123.0, 128.0)] {
                var brow = Path()
                brow.move(to: pt(x0 + tx, y0))
                brow.addLine(to: pt(x1 + tx, y1))
                h.line(brow, Palette.ink.opacity(0.85), 3.2)
            }
        }
        // mask fold under the eyes; a little bump when the mouth opens
        var fold = Path()
        let open: CGFloat = p.mouth == .grin || p.mouth == .o ? 5 : 0
        fold.move(to: pt(80 + tx, 182))
        fold.addQuadCurve(to: pt(120 + tx, 182), control: pt(100 + tx, 186 + open))
        h.line(fold, suitLight, 2.5)

        // headband with a metal plate, knot and fluttering tails
        var bandClip = h
        bandClip.clip(to: hood)
        bandClip.fill(Path(CGRect(x: 20, y: 96, width: 160, height: 13)), red)
        h.fill(Path(roundedRect: CGRect(x: 86 + tx * 0.6, y: 94, width: 28, height: 16), cornerRadius: 4),
               Color(red: 0.75, green: 0.78, blue: 0.83), edge: Color(red: 0.5, green: 0.53, blue: 0.6), width: 1.4)
        h.fill(Paint.sparkle(pt(100 + tx * 0.6, 102), 5, 2), Color(red: 0.5, green: 0.53, blue: 0.6))
        let knot = pt(168, 106)
        let speed = p.stepPhase != nil || p.excitement > 0.5 ? 9.0 : 3.0
        for (k, end) in [(0.0, pt(198, 92)), (1.3, pt(196, 120))] {
            let wave = CGFloat(sin(p.t * speed + k)) * 5
            var tail = Path()
            tail.move(to: knot)
            tail.addQuadCurve(to: pt(end.x, end.y + wave), control: pt(184, (knot.y + end.y) / 2 - wave))
            h.line(tail, red, 6)
        }
        h.fill(circle(knot, 11), red)
    }

    private func drawHandle(_ c: GraphicsContext) {
        c.fill(ellipse(pt(151, 195), 16, 16), gold, edge: Color(red: 0.6, green: 0.45, blue: 0.15), width: 1.2)
        var grip = Path()
        grip.move(to: pt(153, 192))
        grip.addLine(to: pt(171, 172))
        c.line(grip, Palette.ink, 8)
        for i in 0..<3 {
            let q = pt(156 + CGFloat(i) * 5.5, 188 - CGFloat(i) * 6)
            c.fill(Path(roundedRect: CGRect(x: q.x - 1.6, y: q.y - 1.6, width: 3.2, height: 3.2), cornerRadius: 0.5), .white.opacity(0.7))
        }
    }

    /// The drawn katana, held in the left hand and pointing along the arm.
    private func drawKatana(_ c: GraphicsContext, shoulder: CGPoint, angle: Double, armLength: CGFloat) {
        let hand = Paint.armEnd(shoulder: shoulder, angle: angle, length: armLength)
        let dx = (hand.x - shoulder.x) / armLength, dy = (hand.y - shoulder.y) / armLength
        func along(_ d: CGFloat) -> CGPoint { pt(hand.x + dx * d, hand.y + dy * d) }
        var grip = Path()
        grip.move(to: along(-8))
        grip.addLine(to: along(10))
        c.line(grip, Palette.ink, 7)
        c.fill(circle(along(11), 14), gold, edge: Color(red: 0.6, green: 0.45, blue: 0.15), width: 1.2)
        var blade = Path()
        blade.move(to: along(13))
        blade.addQuadCurve(to: along(78), control: pt(along(46).x - dy * 4, along(46).y + dx * 4))
        c.line(blade, Color(red: 0.55, green: 0.6, blue: 0.68), 6.5)
        c.line(blade, steel, 4.5)
        var shine = Path()
        shine.move(to: along(20))
        shine.addLine(to: along(60))
        c.line(shine, .white, 1.2)
        c.fill(circle(hand, 17), glove, edge: suitEdge, width: 1.6)   // hand wraps the grip
    }
}
