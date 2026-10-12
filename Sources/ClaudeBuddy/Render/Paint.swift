import BuddyCore
import SwiftUI

enum Palette {
    static let ink = Color(red: 0.17, green: 0.15, blue: 0.20)
    static let blush = Color(red: 1.0, green: 0.52, blue: 0.58)
    static let heart = Color(red: 1.0, green: 0.36, blue: 0.54)
}

func ellipse(_ c: CGPoint, _ w: CGFloat, _ h: CGFloat) -> Path {
    Path(ellipseIn: CGRect(x: c.x - w / 2, y: c.y - h / 2, width: w, height: h))
}

func circle(_ c: CGPoint, _ d: CGFloat) -> Path { ellipse(c, d, d) }

func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x, y: y) }

extension GraphicsContext {
    func fill(_ path: Path, _ color: Color, edge: Color? = nil, width: CGFloat = 2) {
        fill(path, with: .color(color))
        if let edge { stroke(path, with: .color(edge), lineWidth: width) }
    }

    func line(_ path: Path, _ color: Color, _ width: CGFloat) {
        stroke(path, with: .color(color), style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round))
    }

    /// A copy rotated by `degrees` around `pivot`.
    func rotated(_ degrees: Double, around pivot: CGPoint) -> GraphicsContext {
        var g = self
        g.translateBy(x: pivot.x, y: pivot.y)
        g.rotate(by: .degrees(degrees))
        g.translateBy(x: -pivot.x, y: -pivot.y)
        return g
    }
}

/// What's at the end of an arm.
enum Hand {
    case fist
    case paw(pad: Color)
    case robot
}

struct Limb {
    var fill: Color
    var edge: Color
    var width: CGFloat
    var handSize: CGFloat
    var handFill: Color
    var handEdge: Color
    var hand: Hand
}

enum Paint {
    static func armEnd(shoulder: CGPoint, angle: Double, length: CGFloat) -> CGPoint {
        let a = angle * .pi / 180
        return pt(shoulder.x - length * sin(a), shoulder.y + length * cos(a))
    }

    /// Draws an arm hanging from `shoulder`, rotated by `angle` (0 = straight down). `press` > 1 squashes the hand on the glass.
    static func limb(_ ctx: GraphicsContext, _ limb: Limb, shoulder: CGPoint, angle: Double, length: CGFloat, press: CGFloat = 1) {
        var g = ctx
        g.translateBy(x: shoulder.x, y: shoulder.y)
        g.rotate(by: .degrees(angle))
        let w = limb.width
        let arm = Path(roundedRect: CGRect(x: -w / 2, y: -6, width: w, height: length + 4), cornerRadius: w / 2)
        g.fill(arm, limb.fill, edge: limb.edge, width: 1.8)
        let d = limb.handSize * press
        let c = pt(0, length)
        g.fill(circle(c, d), limb.handFill, edge: limb.handEdge, width: 1.6)
        guard press > 1.05 else { return }
        switch limb.hand {
        case .fist:
            for dx in [-0.22, 0.0, 0.22] {
                var p = Path()
                p.move(to: pt(c.x + dx * d - d * 0.08, c.y - d * 0.18))
                p.addLine(to: pt(c.x + dx * d + d * 0.08, c.y - d * 0.18))
                g.line(p, limb.handEdge, 1.6)
            }
        case .paw(let pad):
            beans(g, at: c, size: d, pad: pad)
        case .robot:
            g.fill(circle(c, d * 0.45), Color(red: 0.4, green: 0.95, blue: 0.89).opacity(0.85))
        }
    }

    /// Toe beans squished on the glass.
    static func beans(_ g: GraphicsContext, at c: CGPoint, size d: CGFloat, pad: Color) {
        g.fill(ellipse(pt(c.x, c.y + d * 0.1), d * 0.42, d * 0.34), pad)
        for (dx, dy) in [(-0.27, -0.2), (0.0, -0.3), (0.27, -0.2)] {
            g.fill(circle(pt(c.x + dx * d, c.y + dy * d), d * 0.17), pad)
        }
    }

    /// Context for the head: tilts around `pivot` and bobs.
    static func head(_ ctx: GraphicsContext, _ pose: Pose, pivot: CGPoint) -> GraphicsContext {
        var g = ctx.rotated(pose.headTilt, around: pivot)
        g.translateBy(x: 0, y: pose.headOffset)
        return g
    }

    /// Cartoon eyes for every mood. `centers` are already shifted for head turn.
    static func eyes(_ ctx: GraphicsContext, _ centers: [CGPoint], size: CGSize, pose: Pose, color: Color = Palette.ink) {
        for c0 in centers {
            let c = pt(c0.x + pose.look.x * 3, c0.y + pose.look.y * 2)
            let w = size.width, h = size.height
            switch pose.mood {
            case .happy:
                var p = Path()
                p.move(to: pt(c.x - w * 0.5, c.y + 3))
                p.addQuadCurve(to: pt(c.x + w * 0.5, c.y + 3), control: pt(c.x, c.y - h * 0.55))
                ctx.line(p, color, 3.5)
            case .sleepy where pose.eyeOpen < 0.35:
                var p = Path()
                p.move(to: pt(c.x - w * 0.5, c.y))
                p.addQuadCurve(to: pt(c.x + w * 0.5, c.y), control: pt(c.x, c.y + h * 0.35))
                ctx.line(p, color, 3)
            case .surprised:
                ctx.fill(circle(c, w * 0.8), color)
                ctx.fill(circle(pt(c.x - 2.5, c.y - 3), 5), .white)
            default:
                let scale: CGFloat = pose.mood == .excited ? 1.18 : 1
                let ew = w * scale
                let eh = max(2.5, h * scale * pose.eyeOpen)
                ctx.fill(ellipse(c, ew, eh), color)
                if pose.eyeOpen > 0.5 {
                    ctx.fill(circle(pt(c.x - ew * 0.18, c.y - eh * 0.22), ew * 0.36), .white)
                    ctx.fill(circle(pt(c.x + ew * 0.2, c.y + eh * 0.2), ew * 0.18), .white.opacity(0.9))
                }
            }
        }
    }

    static func mouth(_ ctx: GraphicsContext, at c: CGPoint, pose: Pose, width: CGFloat = 20, color: Color = Palette.ink) {
        switch pose.mouth {
        case .smile:
            var m = Path()
            m.move(to: pt(c.x - width / 2, c.y - 2))
            m.addQuadCurve(to: pt(c.x + width / 2, c.y - 2), control: pt(c.x, c.y + width * 0.5))
            ctx.line(m, color, 3)
        case .small:
            var m = Path()
            m.move(to: pt(c.x - width * 0.25, c.y))
            m.addQuadCurve(to: pt(c.x + width * 0.25, c.y), control: pt(c.x, c.y + 3))
            ctx.line(m, color, 2.5)
        case .grin:
            var m = Path()
            m.move(to: pt(c.x - width * 0.65, c.y - 4))
            m.addLine(to: pt(c.x + width * 0.65, c.y - 4))
            m.addQuadCurve(to: pt(c.x - width * 0.65, c.y - 4), control: pt(c.x, c.y + width * 1.1))
            m.closeSubpath()
            ctx.fill(m, color)
            var tongue = ctx
            tongue.clip(to: m)
            tongue.fill(ellipse(pt(c.x, c.y + width * 0.5), width * 0.7, width * 0.45), Palette.blush)
        case .o:
            let s = CGFloat(pose.mouthOpen)
            ctx.fill(ellipse(pt(c.x, c.y + 3), width * 0.5 * (0.7 + s * 0.3), width * 0.45 * (0.5 + s * 0.7)), color)
        }
    }

    static func blush(_ ctx: GraphicsContext, _ centers: [CGPoint], size: CGSize, pose: Pose) {
        let alpha = pose.mood == .excited || pose.mood == .happy ? 0.75 : 0.5
        for c in centers { ctx.fill(ellipse(c, size.width, size.height), Palette.blush.opacity(alpha)) }
    }

    static func sparkle(_ c: CGPoint, _ r: CGFloat, _ inner: CGFloat) -> Path {
        var p = Path()
        for i in 0..<8 {
            let a = Double(i) * .pi / 4 - .pi / 2
            let rr = i % 2 == 0 ? r : inner
            let q = pt(c.x + cos(a) * rr, c.y + sin(a) * rr)
            i == 0 ? p.move(to: q) : p.addLine(to: q)
        }
        p.closeSubpath()
        return p
    }

    static func heart(_ c: CGPoint, _ s: CGFloat) -> Path {
        var p = Path()
        p.move(to: pt(c.x, c.y + s * 0.35))
        p.addCurve(to: pt(c.x - s * 0.5, c.y - s * 0.1), control1: pt(c.x - s * 0.1, c.y + s * 0.2), control2: pt(c.x - s * 0.5, c.y + s * 0.15))
        p.addCurve(to: pt(c.x, c.y - s * 0.2), control1: pt(c.x - s * 0.5, c.y - s * 0.45), control2: pt(c.x - s * 0.05, c.y - s * 0.45))
        p.addCurve(to: pt(c.x + s * 0.5, c.y - s * 0.1), control1: pt(c.x + s * 0.05, c.y - s * 0.45), control2: pt(c.x + s * 0.5, c.y - s * 0.45))
        p.addCurve(to: pt(c.x, c.y + s * 0.35), control1: pt(c.x + s * 0.5, c.y + s * 0.15), control2: pt(c.x + s * 0.1, c.y + s * 0.2))
        return p
    }
}
