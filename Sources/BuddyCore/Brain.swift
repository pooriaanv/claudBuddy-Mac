import CoreGraphics
import Foundation

/// Whether the buddy is living on the desktop or busy getting your attention.
public enum PetMode: Equatable {
    case idle, approaching, alert, leaving
}

/// What the buddy is doing while living on the desktop.
public enum Activity: String, CaseIterable, Equatable {
    case sit, lookAround, walk, jump, dance, yawn, wave, sleep
    /// Being carried by the cursor / falling after being dropped (driven by the window, not the brain).
    case dangle, fall
}

public enum Mischief: String, CaseIterable {
    case calm, playful, naughty
}

public struct BrainContext {
    public var now: Double
    /// Buddy's horizontal center on screen and the range it may walk in.
    public var x: Double
    public var minX: Double
    public var maxX: Double
    /// Cursor relative to the buddy's head (screen points, y up), if known.
    public var mouse: CGPoint?
    public var mouseMovedAgo: Double
    /// Seconds since the human last touched mouse or keyboard.
    public var userIdle: Double
    public var mischief: Mischief

    public init(now: Double, x: Double, minX: Double, maxX: Double, mouse: CGPoint? = nil,
                mouseMovedAgo: Double = 99, userIdle: Double = 0, mischief: Mischief = .playful) {
        self.now = now
        self.x = x
        self.minX = minX
        self.maxX = maxX
        self.mouse = mouse
        self.mouseMovedAgo = mouseMovedAgo
        self.userIdle = userIdle
        self.mischief = mischief
    }
}

/// Small, seedable RNG so behavior can be tested deterministically.
public struct SplitMix64: RandomNumberGenerator {
    private var state: UInt64
    public init(seed: UInt64) { state = seed }
    public mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

/// Decides what the buddy does next while idling. New behaviors go here (and get a pose in `Animator`).
public final class Brain {
    public private(set) var activity: Activity = .sit
    public private(set) var activityStart: Double = 0
    /// Walking direction: 1 = right, -1 = left.
    public private(set) var direction: Double = 1
    private var until: Double = 4
    private var lastWave = -100.0
    private var lastChase = -100.0
    private var rng: SplitMix64

    public init(seed: UInt64 = UInt64.random(in: 0...UInt64.max)) {
        rng = SplitMix64(seed: seed)
    }

    public func elapsed(at now: Double) -> Double { now - activityStart }

    public static func walkSpeed(_ m: Mischief) -> Double { m == .naughty ? 60 : 40 }

    /// Advances the brain; returns the horizontal velocity (points/second) to move the buddy by.
    @discardableResult
    public func tick(_ c: BrainContext) -> Double {
        if activity == .dangle || activity == .fall { return 0 }

        // Nap while the human is away; wake up with a yawn.
        if activity == .sleep {
            if c.userIdle < 1 { start(.yawn, at: c.now, for: 2.2) }
            return 0
        }
        if c.userIdle > (c.mischief == .calm ? 90 : 150) {
            start(.sleep, at: c.now, for: .infinity)
            return 0
        }

        reactToCursor(c)
        if c.now >= until { pickNext(c) }

        guard activity == .walk else { return 0 }
        let blocked = (direction > 0 && c.x >= c.maxX) || (direction < 0 && c.x <= c.minX)
        if blocked {
            if chance(0.5) {
                direction = -direction
            } else {
                start(.sit, at: c.now, for: duration(.sit, c.mischief))
                return 0
            }
        }
        return direction * Self.walkSpeed(c.mischief)
    }

    /// Clicked: hop happily (or wake up).
    public func poke(at now: Double) {
        if activity == .sleep { start(.yawn, at: now, for: 2.2) } else { start(.jump, at: now, for: 0.6) }
    }

    public func pickUp(at now: Double) { start(.dangle, at: now, for: .infinity) }
    public func drop(at now: Double) { start(.fall, at: now, for: .infinity) }
    public func land(at now: Double) { start(.jump, at: now, for: 0.6) }
    public func settle(at now: Double) { start(.sit, at: now, for: 4) }

    // MARK: -

    private func reactToCursor(_ c: BrainContext) {
        guard let m = c.mouse, c.mouseMovedAgo < 0.4, activity == .sit || activity == .lookAround else { return }
        let dist = hypot(m.x, m.y)
        if dist < 170 && c.now - lastWave > 25 {
            lastWave = c.now
            start(.wave, at: c.now, for: 1.8)
        } else if c.mischief == .naughty && dist < 500 && abs(m.x) > 90 && c.now - lastChase > 8 {
            // Naughty buddies chase the cursor for a bit.
            lastChase = c.now
            direction = m.x > 0 ? 1 : -1
            start(.walk, at: c.now, for: min(3, abs(m.x) / Self.walkSpeed(c.mischief)))
        }
    }

    private func pickNext(_ c: BrainContext) {
        let table: [(Activity, Double)]
        switch c.mischief {
        case .calm: table = [(.sit, 6), (.lookAround, 3), (.yawn, 1)]
        case .playful: table = [(.sit, 5), (.lookAround, 2), (.walk, 4), (.jump, 1), (.dance, 1), (.yawn, 0.7)]
        case .naughty: table = [(.sit, 2), (.lookAround, 1), (.walk, 5), (.jump, 2), (.dance, 2), (.yawn, 0.4)]
        }
        var next = weighted(table)
        if next == activity && next != .sit { next = .sit }
        if next == .walk {
            let room = c.maxX - c.minX
            if room < 40 {
                next = .sit
            } else if c.x < c.minX + room * 0.2 {
                direction = 1
            } else if c.x > c.maxX - room * 0.2 {
                direction = -1
            } else {
                direction = chance(0.5) ? 1 : -1
            }
        }
        start(next, at: c.now, for: duration(next, c.mischief))
    }

    private func duration(_ a: Activity, _ m: Mischief) -> Double {
        switch a {
        case .sit:
            switch m {
            case .calm: return random(6...14)
            case .playful: return random(4...10)
            case .naughty: return random(2.5...6)
            }
        case .lookAround: return random(3...5)
        case .walk: return random(2.5...6)
        case .jump: return 0.6
        case .dance: return 3
        case .yawn: return 2.2
        case .wave: return 1.8
        case .sleep, .dangle, .fall: return .infinity
        }
    }

    private func start(_ a: Activity, at now: Double, for seconds: Double) {
        activity = a
        activityStart = now
        until = now + seconds
    }

    private func weighted(_ table: [(Activity, Double)]) -> Activity {
        var r = random(0...table.reduce(0) { $0 + $1.1 })
        for (a, w) in table {
            if r < w { return a }
            r -= w
        }
        return table[0].0
    }

    private func random(_ range: ClosedRange<Double>) -> Double { Double.random(in: range, using: &rng) }
    private func chance(_ p: Double) -> Bool { random(0...1) < p }
}
