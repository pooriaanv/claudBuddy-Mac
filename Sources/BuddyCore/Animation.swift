import CoreGraphics
import Foundation

public func smooth(_ x: Double) -> Double {
    let v = min(1, max(0, x))
    return v * v * (3 - 2 * v)
}

public func lerp(_ a: Double, _ b: Double, _ t: Double) -> Double { a + (b - a) * t }

/// Natural-looking blinks from two overlapping rhythms. 1 = open.
public func eyeOpen(_ t: Double) -> Double {
    func bump(_ period: Double, _ offset: Double) -> Double {
        let local = (t + offset).truncatingRemainder(dividingBy: period)
        return local < 0.15 ? sin(local / 0.15 * .pi) : 0
    }
    return 1 - 0.92 * max(bump(4.1, 0), bump(6.7, 2.3))
}

// MARK: - Knocking

public enum Knocking {
    /// Hit times (seconds since the alert began): three quick knocks per cycle, frequent at first, then calmer.
    public static func schedule(from start: Double) -> [Double] {
        var out: [Double] = []
        var c = start
        for i in 0..<60 {
            for k in 0..<3 { out.append(c + Double(k) * 0.24) }
            c += i < 3 ? 3.2 : 12
        }
        return out
    }

    public struct State {
        public var armUp = 0.0
        public var depth = 0.0
        public var since = 99.0
        public var recent: [Double] = []
    }

    public static func state(at e: Double, hits: [Double]) -> State {
        var st = State()
        var i = 0
        while i + 2 < hits.count {
            let a = hits[i], b = hits[i + 2]
            if e > a - 0.5 && e < b + 0.6 {
                let up = (e - (a - 0.45)) / 0.3
                let down = ((b + 0.55) - e) / 0.35
                st.armUp = max(st.armUp, smooth(min(up, down)))
            }
            i += 3
        }
        for h in hits {
            let d = e - h
            if d > -0.12 && d < 0.1 {
                st.depth = max(st.depth, d < 0 ? 1 - pow(d / 0.12, 2) : 1 - pow(d / 0.1, 2))
            }
            if d >= 0 {
                st.since = min(st.since, d)
                if d < 2.5 { st.recent.append(d) }
            }
        }
        return st
    }
}

// MARK: - Animator

public struct AnimationInput {
    public var t: Double
    public var mode: PetMode = .idle
    public var activity: Activity = .sit
    public var activityElapsed: Double = 0
    public var direction: Double = 1
    public var alertElapsed: Double = 0
    public var knockHits: [Double] = []
    /// Where to look (-1...1), e.g. toward the cursor; nil lets the eyes wander.
    public var lookTarget: CGPoint?
    public var heartAges: [Double] = []
    /// Extra swing (degrees) while carried, from drag speed.
    public var swing: Double = 0
    /// Live posture transition from a `PostureTracker`. Nil = assume the usual previous posture (previews, snapshots).
    public var posture: PostureTracker.State?

    public init(t: Double) { self.t = t }
}

/// Remembers the real previous posture so transitions start from where the body actually is.
public struct PostureTracker {
    public struct State: Equatable {
        public var from: Posture
        public var to: Posture
        public var blend: Double
    }

    public private(set) var from: Posture = .sit
    public private(set) var to: Posture = .sit
    private var start = -100.0
    private var duration = 0.3

    public init() {}

    public mutating func update(target: Posture, duration: Double, now: Double) {
        guard target != to else { return }
        // Start from whichever posture the body is mostly in right now.
        from = blend(at: now) >= 0.5 ? to : from
        to = target
        start = now
        self.duration = duration
    }

    public func blend(at now: Double) -> Double { duration <= 0 ? 1 : smooth((now - start) / duration) }
    public func state(at now: Double) -> State { State(from: from, to: to, blend: blend(at: now)) }
}

/// Turns state + time into a pose. Pure and deterministic, so it's easy to preview and test.
public enum Animator {
    public static func scene(_ i: AnimationInput) -> PetScene {
        var s = PetScene()
        var p = Pose()
        let t = i.t
        let e = i.activityElapsed
        p.t = t
        p.breathe = 1 + sin(t * 1.8) * 0.018
        p.eyeOpen = eyeOpen(t)
        p.headTilt = sin(t * 1.8) * 6 + sin(t * 0.7) * 2
        p.headOffset = sin(t * 3.6) * 1.5
        let armSwing = sin(t * 1.8) * 5
        p.leftArm = 14 - armSwing
        p.rightArm = -14 + armSwing
        p.look = i.lookTarget ?? CGPoint(x: sin(t * 0.37) * sin(t * 0.13), y: 0)

        let excited = i.mode == .approaching || i.mode == .alert
        if excited {
            p.mood = .excited
            p.mouth = .grin
            p.excitement = 1
            p.wag = 2.5
            p.look = .zero
            p.headTilt = sin(t * 3.2) * 4
            let k = Knocking.state(at: i.alertElapsed, hits: i.knockHits)
            p.eyeOpen = min(max(eyeOpen(t * 0.6), 0.3), 1 - k.depth * 0.4)
            p.lift = -abs(sin(t * 5.5)) * 3 * (1 - k.armUp * 0.7)
            p.rightArm = lerp(p.rightArm, -125 + k.depth * 10, k.armUp)
            p.reach = k.armUp
            p.rightArmInFront = k.armUp >= 0.5
            p.press = 1 + k.depth * 1.3
            s.knockAges = k.recent
            if k.since < 0.14 {
                let f = 1 - k.since / 0.14
                s.shake = CGSize(width: sin(k.since * 95) * 2.2 * f, height: cos(k.since * 80) * 1.2 * f)
            }
        } else {
            apply(i.activity, elapsed: e, input: i, pose: &p, scene: &s)
        }

        p.facing = max(-1, min(1, i.direction))
        if let live = i.posture {
            p.posture = live.to
            p.postureFrom = live.from
            p.postureBlend = live.blend
        } else if excited {
            p.posture = .front
            p.postureFrom = .sit
            p.postureBlend = smooth(i.alertElapsed / 0.45)
        } else {
            let (posture, from, blendTime) = Self.posture(for: i.activity)
            p.posture = posture
            p.postureFrom = from
            p.postureBlend = smooth(e / blendTime)
        }
        p.airborne = p.lift < -3 || i.activity == .dangle || i.activity == .fall

        if !excited && i.activity != .sleep && i.heartAges.contains(where: { $0 < 1.2 }) {
            p.mood = .happy
            p.mouth = .grin
            p.wag = 3
        }
        s.heartAges = i.heartAges.filter { $0 < 1.6 }
        s.pose = p
        return s
    }

    /// The posture the body should be heading to, and how long getting there takes.
    public static func targetPosture(mode: PetMode, activity: Activity) -> (Posture, Double) {
        if mode == .approaching || mode == .alert { return (.front, 0.45) }
        let (to, _, time) = posture(for: activity)
        return (to, time)
    }

    /// Target posture per activity, the posture it usually starts from, and how long the change takes.
    static func posture(for activity: Activity) -> (Posture, Posture, Double) {
        switch activity {
        case .sit, .lookAround, .wave: return (.sit, .stand, 0.35)
        case .walk, .jump: return (.stand, .sit, 0.3)
        case .dance: return (.rear, .sit, 0.3)
        case .yawn: return (.stretch, .sit, 0.4)
        case .sleep: return (.lie, .sit, 0.8)
        case .dangle, .fall: return (.hang, .sit, 0.15)
        }
    }

    private static func apply(_ activity: Activity, elapsed e: Double, input i: AnimationInput,
                              pose p: inout Pose, scene s: inout PetScene) {
        let t = i.t
        switch activity {
        case .sit:
            break
        case .lookAround:
            let sweep = sin(e * 1.4)
            p.look = CGPoint(x: sweep, y: -0.2)
            p.turn = sweep * 0.5
            p.headTilt += sweep * 4
        case .walk:
            let ph = e * 9
            p.stepPhase = ph
            p.lift = -abs(sin(ph)) * 3
            p.lean = i.direction * 5
            p.turn = i.direction * 0.6
            p.look = CGPoint(x: i.direction, y: 0)
            p.leftArm = 14 + sin(ph) * 20
            p.rightArm = -14 + sin(ph) * 20
            p.headTilt = sin(ph) * 2
            p.wag = 2
        case .jump:
            if e < 0.6 {
                let h = sin(e / 0.6 * .pi)
                p.lift = -h * 26
                p.leftArm = 14 + h * 60
                p.rightArm = -14 - h * 60
                p.mood = .happy
                p.mouth = .grin
                p.excitement = h
            }
        case .dance:
            let b = e * 6
            p.lean = sin(b) * 8
            p.lift = -abs(sin(b)) * 6
            p.leftArm = 110 + sin(b) * 40
            p.rightArm = -110 + sin(b) * 40
            p.headTilt = sin(b) * 8
            p.mood = .happy
            p.mouth = .grin
            p.wag = 3
            p.excitement = 0.6
            s.dancing = true
        case .yawn:
            let q = sin(min(1, e / 2.2) * .pi)
            p.mouth = .o
            p.mouthOpen = 0.4 + q
            p.eyeOpen = 1 - 0.85 * q
            p.leftArm = lerp(p.leftArm, 160, q)
            p.rightArm = lerp(p.rightArm, -160, q)
            p.headTilt = -6 * q
            if q > 0.3 { p.mood = .sleepy }
        case .wave:
            let r = smooth(e / 0.25) * smooth((1.8 - e) / 0.25)
            p.rightArm = lerp(p.rightArm, -150 + sin(e * 14) * 22, r)
            p.rightArmInFront = r > 0.5
            p.mood = .happy
            p.mouth = .grin
            p.look = .zero
        case .sleep:
            p.mood = .sleepy
            p.mouth = .small
            p.eyeOpen = 0
            p.headTilt = 9 + sin(t * 0.8) * 2
            p.headOffset = 6
            p.breathe = 1 + sin(t * 1.2) * 0.03
            p.leftArm = 10
            p.rightArm = -10
            p.look = .zero
            p.wag = 0.2
            s.sleeping = true
        case .dangle:
            p.swing = i.swing + sin(t * 5) * 4
            p.mood = .surprised
            p.mouth = .o
            p.mouthOpen = 0.6
            p.stepPhase = t * 14
            p.leftArm = 45 + sin(t * 7) * 10
            p.rightArm = -45 - sin(t * 7) * 10
            p.look = .zero
            p.wag = 3
            s.shadow = 0.25
        case .fall:
            p.mood = .surprised
            p.mouth = .o
            p.leftArm = 150
            p.rightArm = -150
            p.look = .zero
            s.shadow = 0.4
        }
    }
}
