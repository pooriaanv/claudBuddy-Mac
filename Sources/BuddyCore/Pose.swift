import CoreGraphics
import Foundation

public enum Mood: Equatable {
    case normal, excited, happy, sleepy, surprised
}

public enum MouthShape: Equatable {
    case smile, grin, o, small
}

/// Whole-body posture. Bipeds mostly ignore it; four-legged skins use it to sit, stand, rear up, stretch, lie down or hang.
/// `front` = turned fully toward the viewer, sitting (used when knocking on the glass).
public enum Posture: Equatable, CaseIterable {
    case stand, sit, rear, stretch, lie, hang, front
}

/// The available characters. Each has a matching skin in the app's `Render/Skins` folder.
public enum SkinID: String, CaseIterable, Identifiable {
    case buddy, kitty, puppy, robo
    public var id: String { rawValue }
    public var nameKey: L10nKey {
        switch self {
        case .buddy: return .skinBuddy
        case .kitty: return .skinKitty
        case .puppy: return .skinPuppy
        case .robo: return .skinRobo
        }
    }
}

/// Everything a skin needs to draw one frame.
/// Character space is 200×300 points, y grows downward, feet rest at y ≈ 288.
public struct Pose: Equatable {
    public var t: Double = 0
    public var mood: Mood = .normal
    public var eyeOpen: Double = 1
    /// Where the eyes point, -1...1 on each axis.
    public var look: CGPoint = .zero
    /// -1...1: face features slide sideways to fake a head turn.
    public var turn: Double = 0
    /// Head rotation in degrees around the neck.
    public var headTilt: Double = 0
    /// Head vertical offset (+ = down).
    public var headOffset: Double = 0
    public var breathe: Double = 1
    /// Whole-body vertical offset (- = up), e.g. jumping or bouncing.
    public var lift: Double = 0
    /// Degrees, rotating around the feet (walking/dancing).
    public var lean: Double = 0
    /// Degrees, rotating around the top of the head (being carried).
    public var swing: Double = 0
    /// Radians while walking or kicking; nil when standing.
    public var stepPhase: Double?
    /// Arm angles in degrees; 0 hangs straight down. Left + swings outward-left, right - swings outward-right.
    public var leftArm: Double = 14
    public var rightArm: Double = -14
    /// 0...1: right arm stretched out toward the glass.
    public var reach: Double = 0
    public var rightArmInFront = false
    /// Right hand scale while pressed on the glass (1 = normal).
    public var press: Double = 1
    public var mouth: MouthShape = .smile
    public var mouthOpen: Double = 1
    /// Tail wag speed multiplier.
    public var wag: Double = 1
    /// 0...1, for ears / antenna perking up.
    public var excitement: Double = 0
    /// Posture, blending from `postureFrom` (0) to `posture` (1).
    public var posture: Posture = .sit
    public var postureFrom: Posture = .sit
    public var postureBlend: Double = 1
    /// 1 = facing right, -1 = facing left (side-view skins flip).
    public var facing: Double = 1
    /// Feet off the ground (jumping, carried, falling).
    public var airborne = false

    public init() {}

    /// Eases the continuous parts of the pose toward `target`, so switching activities never snaps.
    /// `k` is the fraction to move this frame (0...1).
    public func eased(toward target: Pose, _ k: Double) -> Pose {
        func mix(_ a: Double, _ b: Double) -> Double { a + (b - a) * k }
        var p = target
        p.lift = mix(lift, target.lift)
        p.lean = mix(lean, target.lean)
        p.swing = mix(swing, target.swing)
        p.headTilt = mix(headTilt, target.headTilt)
        p.headOffset = mix(headOffset, target.headOffset)
        p.turn = mix(turn, target.turn)
        p.leftArm = mix(leftArm, target.leftArm)
        p.rightArm = mix(rightArm, target.rightArm)
        p.look = CGPoint(x: mix(look.x, target.look.x), y: mix(look.y, target.look.y))
        return p
    }

    public func footLift(left: Bool) -> Double {
        guard let p = stepPhase else { return 0 }
        let s = sin(p)
        return (left ? max(0, s) : max(0, -s)) * 7
    }
}

public struct Bubble: Equatable {
    public var title: String
    public var subtitle: String
    public var rtl: Bool
    /// 0...1 pop-in progress.
    public var appear: Double

    public init(title: String, subtitle: String, rtl: Bool, appear: Double) {
        self.title = title
        self.subtitle = subtitle
        self.rtl = rtl
        self.appear = appear
    }
}

/// One frame: a pose plus effects around it.
public struct PetScene: Equatable {
    public var pose = Pose()
    public var shake: CGSize = .zero
    /// Ages (seconds) of recent knocks on the glass.
    public var knockAges: [Double] = []
    /// Ages of hearts floating up after a pat.
    public var heartAges: [Double] = []
    public var sleeping = false
    public var dancing = false
    public var bubble: Bubble?
    /// Small, calm tag above the head: a session finished while you were looking elsewhere in its app.
    public var hint: String?
    public var knockText = "Knock!"
    /// 0...1 ground shadow strength (fades when lifted off the ground).
    public var shadow: Double = 1

    public init() {}
}
