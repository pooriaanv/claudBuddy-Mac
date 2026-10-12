import BuddyCore
import SwiftUI

/// Side-view four-legged body shared by Kitty and Puppy: the body is in profile, the (big, cute) head faces you.
/// All coordinates are for facing right; the skin mirrors itself when facing left.
struct QuadrupedRig {
    static let bodyLength: CGFloat = 74
    static let floor: CGFloat = 288
    /// Where the front paw presses the glass while rearing up.
    static let knockTarget = pt(166, 176)

    let pose: Pose
    /// Body angle in degrees around the hip; negative lifts the chest.
    let theta: Double
    let drop: CGFloat
    /// 0...1: hind legs folded into a sitting haunch.
    let haunch: Double
    /// 0...1: legs tucked under (lying down).
    let tuck: Double
    /// 0...1: front legs stretched forward (yawn stretch).
    let stretch: Double
    let hip: CGPoint
    /// Hopping gait (bunnies): front feet together, hind feet together, body bouncing.
    let hops: Bool
    /// Vertical bounce of the whole body while hopping (negative = up).
    let hop: CGFloat

    init(_ p: Pose, hops: Bool = false) {
        pose = p
        self.hops = hops
        hop = hops && p.stepPhase != nil && !p.airborne ? -CGFloat(abs(sin((p.stepPhase ?? 0) / 2))) * 14 : 0
        // theta, drop, haunch, tuck, stretch
        func params(_ s: Posture) -> [Double] {
            switch s {
            case .stand: return [0, 0, 0, 0, 0]
            case .sit: return [-38, 4, 1, 0, 0]
            case .rear: return [-68, 0, 1, 0, 0]
            case .stretch: return [14, 0, 0, 0, 1]
            case .lie: return [0, 22, 0, 1, 0]
            case .hang: return [-80, -6, 0, 0, 0]
            case .front: return [-38, 4, 1, 0, 0]   // side view never shows it; behaves like sitting
            }
        }
        let v = zip(params(p.postureFrom), params(p.posture)).map { lerp($0, $1, p.postureBlend) }
        theta = v[0]
        drop = CGFloat(v[1])
        haunch = v[2]
        tuck = v[3]
        stretch = v[4]
        hip = pt(52, 236 + drop + hop)
    }

    /// A point given relative to the hip along the body axis, in character space.
    func world(_ l: CGPoint) -> CGPoint {
        let a = theta * .pi / 180
        return pt(hip.x + l.x * cos(a) - l.y * sin(a), hip.y + l.x * sin(a) + l.y * cos(a))
    }

    var chest: CGPoint { world(pt(Self.bodyLength, 0)) }
    var rump: CGPoint { world(pt(-24, -8)) }
    var headCenter: CGPoint { pt(chest.x + 16, chest.y - 50) }

    func attach(front: Bool, near: Bool) -> CGPoint {
        world(pt((front ? 66 : 6) - (near ? 0 : 13), 22))
    }

    /// How much a front paw is lifted (waving, batting), read from the upright arm angles.
    func pawRaise(near: Bool) -> Double {
        guard pose.posture == .sit || pose.posture == .rear || pose.posture == .front else { return 0 }
        return smooth(((near ? -pose.rightArm : pose.leftArm) - 35) / 90)
    }

    func foot(front: Bool, near: Bool) -> CGPoint {
        let a = attach(front: front, near: near)
        let p = pose
        // diagonal pairs move together, like a real walk
        let pairOffset: Double = hops ? (front ? 0 : .pi) : (front == near ? 0 : .pi)
        let phase = (p.stepPhase ?? 0) + pairOffset
        let raise = front ? CGFloat(pawRaise(near: near)) : 0

        if p.airborne || Self.floor - a.y > (front ? 82 : 44) {
            let kick = p.stepPhase != nil ? CGFloat(sin(phase)) * 6 : 0
            return pt(a.x + 8 + raise * 14, a.y + 26 - raise * 30 + kick)
        }
        var dx: CGFloat = 0, lift: CGFloat = 0
        if p.stepPhase != nil {
            dx = CGFloat(sin(phase)) * 9
            lift = CGFloat(max(0, cos(phase))) * 7
        }
        if front { dx += CGFloat(stretch) * 22 }
        var f = pt(a.x + dx, Self.floor - 5 - lift + hop)
        if raise > 0 {
            let wave = CGFloat(sin(p.t * 14)) * 6 * raise
            f = pt(f.x + raise * 18, f.y - raise * (f.y - a.y + 14) + wave)
        }
        return f
    }
}

/// A four-legged skin supplies colors, tail shapes, body markings and a head; the rig does the rest.
protocol QuadrupedSkin: Skin {
    var fur: Color { get }
    var furEdge: Color { get }
    var farFur: Color { get }
    var paw: Color { get }
    var pad: Color { get }
    var tailWidth: CGFloat { get }
    var tailTip: Color? { get }
    var wagSpeed: Double { get }
    var wagAmount: Double { get }
    /// Tail curls around the front paws (in front of the body) when sitting or lying.
    var wrapsTail: Bool { get }
    /// Hops instead of walking.
    var hops: Bool { get }
    /// Tail control point 1, control point 2 and tip, relative to the rump.
    func tailShape(_ posture: Posture) -> [CGPoint]
    /// Drawn in body space (rotated with the body), using `rig.hip` as the origin.
    func drawMarkings(_ body: GraphicsContext, _ rig: QuadrupedRig)
    /// Drawn between body and head (collars etc).
    func drawNeck(_ g: GraphicsContext, _ rig: QuadrupedRig)
    /// Front-facing head drawn around (100, 146), about 150 wide; scaled down by the rig.
    func drawHead(_ h: GraphicsContext, _ pose: Pose, tx: CGFloat)

    // Front view (sitting, facing the viewer — used while knocking).
    func frontTail(_ pose: Pose) -> (path: Path, inFront: Bool)
    func drawFrontMarkings(_ g: GraphicsContext)
    func drawFrontNeck(_ g: GraphicsContext)
}

/// Front view geometry: the right front paw lifts from here to tap the glass.
enum FrontSit {
    static let shoulder = pt(114, 228)
    static let legLength: CGFloat = 56
    static let reachLength: CGFloat = 52
}

extension QuadrupedSkin {
    var rightShoulder: CGPoint { QuadrupedRig.knockTarget }
    var reachLength: CGFloat { 0 }
    var usesLean: Bool { false }

    /// Four-legged buddies always knock from the front view.
    func knockPoint(_ pose: Pose) -> CGPoint {
        Paint.armEnd(shoulder: FrontSit.shoulder, angle: -115, length: FrontSit.reachLength)
    }

    var wrapsTail: Bool { false }
    var hops: Bool { false }

    func drawNeck(_ g: GraphicsContext, _ rig: QuadrupedRig) {}
    func drawFrontNeck(_ g: GraphicsContext) {}

    /// Turning toward you: the side and front bodies crossfade while one head glides between their positions
    /// (crossfading two faces would show four eyes).
    func draw(_ ctx: GraphicsContext, pose p: Pose) {
        let f = p.posture == .front ? p.postureBlend : (p.postureFrom == .front ? 1 - p.postureBlend : 0)
        if f <= 0.01 {
            drawSide(ctx, pose: p)
            placeHead(ctx, p, sideHead(p))
            return
        }
        if f >= 0.99 {
            drawFrontBody(ctx, pose: p)
            placeHead(ctx, p, frontHead)
            drawFrontPaw(ctx, pose: p)
            return
        }
        var side = ctx
        side.opacity = 1 - f
        side.drawLayer { drawSide($0, pose: p) }
        var front = ctx
        front.opacity = f
        front.drawLayer { drawFrontBody($0, pose: p) }

        let a = sideHead(p), b = frontHead, k = CGFloat(f)
        placeHead(ctx, p, (center: pt(a.center.x + (b.center.x - a.center.x) * k, a.center.y + (b.center.y - a.center.y) * k),
                           scale: a.scale + (b.scale - a.scale) * k, tx: a.tx * (1 - k)))
        front.drawLayer { drawFrontPaw($0, pose: p) }
    }

    private typealias HeadPlacement = (center: CGPoint, scale: CGFloat, tx: CGFloat)

    private var frontHead: HeadPlacement { (pt(100, 150), 0.88, 0) }

    /// Where the side view puts the head. The head itself is never mirrored (it faces you), only its position follows
    /// the body as it turns around.
    private func sideHead(_ p: Pose) -> HeadPlacement {
        let c = QuadrupedRig(p, hops: hops).headCenter
        return (pt(100 + (c.x - 100) * CGFloat(p.facing), c.y), 0.74, CGFloat(p.turn + 0.25 * p.facing) * 8)
    }

    private func placeHead(_ g: GraphicsContext, _ p: Pose, _ at: HeadPlacement) {
        var h = g
        h.translateBy(x: at.center.x, y: at.center.y + p.headOffset)
        h.rotate(by: .degrees(p.headTilt * 0.6))
        h.scaleBy(x: at.scale, y: at.scale)
        h.translateBy(x: -100, y: -146)
        drawHead(h, p, tx: at.tx)
    }

    private var frontLeg: Limb {
        Limb(fill: fur, edge: furEdge, width: 16, handSize: 19, handFill: paw, handEdge: furEdge, hand: .paw(pad: pad))
    }

    /// Sitting, turned fully toward the viewer (everything but the head and the knocking paw).
    func drawFrontBody(_ g: GraphicsContext, pose p: Pose) {
        let tail = frontTail(p)
        func strokeTail() {
            g.line(tail.path, furEdge, tailWidth + 3)
            g.line(tail.path, fur, tailWidth)
        }
        if !tail.inFront { strokeTail() }

        // haunches and hind paws
        for x: CGFloat in [64, 136] {
            g.fill(ellipse(pt(x, 262), 50, 50), fur, edge: furEdge)
            g.fill(ellipse(pt(x + (x < 100 ? -6 : 6), 283), 26, 12), paw, edge: furEdge, width: 1.6)
        }
        var b = g
        b.translateBy(x: 100, y: 284)
        b.scaleBy(x: 1, y: p.breathe)
        b.translateBy(x: -100, y: -284)
        b.fill(ellipse(pt(100, 242), 82, 88), fur, edge: furEdge)
        drawFrontMarkings(b)

        Paint.limb(g, frontLeg, shoulder: pt(86, 228), angle: 0, length: FrontSit.legLength)
        if p.reach < 0.01 { Paint.limb(g, frontLeg, shoulder: FrontSit.shoulder, angle: 0, length: FrontSit.legLength) }
        if tail.inFront { strokeTail() }
        drawFrontNeck(g)
    }

    /// The right front paw lifting to tap the glass (drawn over the head — it's closest to you).
    func drawFrontPaw(_ g: GraphicsContext, pose p: Pose) {
        guard p.reach >= 0.01 else { return }
        let k = CGFloat(p.reach)
        let length = FrontSit.legLength + (FrontSit.reachLength - FrontSit.legLength) * k
        Paint.limb(g, frontLeg, shoulder: FrontSit.shoulder, angle: Double(k) * p.rightArm, length: length, press: CGFloat(p.press))
    }

    /// The body in profile (no head). `facing` between -1 and 1 squeezes it through the middle: turning around.
    func drawSide(_ ctx: GraphicsContext, pose p: Pose) {
        var g = ctx
        let facing = CGFloat(p.facing)
        let flip = abs(facing) < 0.06 ? (facing < 0 ? -0.06 : 0.06) : facing
        g.translateBy(x: 100, y: 0)
        g.scaleBy(x: flip, y: 1)
        g.translateBy(x: -100, y: 0)
        let rig = QuadrupedRig(p, hops: hops)
        let legsVisible = rig.tuck < 0.5
        let sitting = rig.haunch > 0.5
        let tailInFront = wrapsTail && (p.posture == .sit || p.posture == .lie) && p.postureBlend > 0.5

        if !tailInFront { drawTail(g, rig) }

        if legsVisible {
            leg(g, rig.attach(front: true, near: false), rig.foot(front: true, near: false), color: farFur)
            if !sitting { leg(g, rig.attach(front: false, near: false), rig.foot(front: false, near: false), color: farFur) }
        }

        var body = g.rotated(rig.theta, around: rig.hip)
        body.translateBy(x: 0, y: rig.hip.y)
        body.scaleBy(x: 1, y: p.breathe)
        body.translateBy(x: 0, y: -rig.hip.y)
        let torso = Path(roundedRect: CGRect(x: rig.hip.x - 30, y: rig.hip.y - 30,
                                             width: QuadrupedRig.bodyLength + 56, height: 58), cornerRadius: 29)
        body.fill(torso, fur, edge: furEdge)
        drawMarkings(body, rig)

        if legsVisible {
            if sitting {
                let h = pt(rig.hip.x + 14, QuadrupedRig.floor - 23)
                g.fill(ellipse(h, 56, 46), fur, edge: furEdge)
                g.fill(ellipse(pt(h.x + 22, QuadrupedRig.floor - 5), 24, 12), paw, edge: furEdge, width: 1.6)
            } else {
                leg(g, rig.attach(front: false, near: true), rig.foot(front: false, near: true), color: fur)
            }
            leg(g, rig.attach(front: true, near: true), rig.foot(front: true, near: true), color: fur)
        } else {
            // loaf: front paws peeking out
            for dx: CGFloat in [2, 18] {
                g.fill(ellipse(pt(rig.chest.x + dx, QuadrupedRig.floor - 6), 22, 12), paw, edge: furEdge, width: 1.6)
            }
        }

        if tailInFront { drawTail(g, rig) }
        drawNeck(g, rig)
    }

    private func leg(_ g: GraphicsContext, _ a: CGPoint, _ f: CGPoint, color: Color, press: CGFloat = 1) {
        var l = Path()
        l.move(to: a)
        l.addLine(to: f)
        g.line(l, furEdge, 18)
        g.line(l, color, 15)
        if press > 1.05 {
            // paw pressed flat on the glass, toe beans showing
            let d = 18 * press
            g.fill(circle(f, d), paw, edge: furEdge, width: 1.6)
            Paint.beans(g, at: f, size: d, pad: pad)
        } else {
            g.fill(ellipse(pt(f.x + 3, f.y), 21, 12), paw, edge: furEdge, width: 1.6)
        }
    }

    private func drawTail(_ g: GraphicsContext, _ rig: QuadrupedRig) {
        let p = rig.pose
        let from = tailShape(p.postureFrom), to = tailShape(p.posture)
        let k = CGFloat(p.postureBlend)
        func mix(_ i: Int) -> CGPoint { pt(from[i].x + (to[i].x - from[i].x) * k, from[i].y + (to[i].y - from[i].y) * k) }
        let calm: CGFloat = p.posture == .sit || p.posture == .lie ? 0.4 : 1
        let sway = CGFloat(sin(p.t * wagSpeed * p.wag)) * CGFloat(wagAmount) * calm
        let r = rig.rump
        let c1 = mix(0), c2 = mix(1), tip = mix(2)
        let end = pt(r.x + tip.x + sway, r.y + tip.y)
        var path = Path()
        path.move(to: r)
        path.addCurve(to: end, control1: pt(r.x + c1.x, r.y + c1.y), control2: pt(r.x + c2.x + sway * 0.6, r.y + c2.y))
        g.line(path, furEdge, tailWidth + 3)
        g.line(path, fur, tailWidth)
        if let tailTip { g.fill(circle(end, tailWidth - 1), tailTip) }
    }
}
