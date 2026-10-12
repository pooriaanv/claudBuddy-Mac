import BuddyCore
import SwiftUI

/// A character's look. Draws one `Pose` in character space (200×300, feet at y ≈ 288).
///
/// To add a character: add a case to `SkinID` (BuddyCore), a name to `L10n`, a skin file here,
/// and register it in `SkinCatalog`.
protocol Skin {
    /// Where the right arm attaches; with `reachLength` it defines where the hand meets the glass.
    var rightShoulder: CGPoint { get }
    var reachLength: CGFloat { get }
    var tone: KnockTone { get }
    /// Whether the renderer should tilt the whole body when walking/dancing.
    var usesLean: Bool { get }
    /// Where the knock lands on the glass, in character space.
    func knockPoint(_ pose: Pose) -> CGPoint
    func draw(_ ctx: GraphicsContext, pose: Pose)
}

extension Skin {
    var usesLean: Bool { true }

    /// Upright skins: the right arm at -115° when fully reached.
    func knockPoint(_ pose: Pose) -> CGPoint { Paint.armEnd(shoulder: rightShoulder, angle: -115, length: reachLength) }

    /// Arm length for the current reach.
    func armLength(rest: CGFloat, _ pose: Pose) -> CGFloat {
        rest + (reachLength - rest) * CGFloat(pose.reach)
    }
}

enum SkinCatalog {
    static func skin(_ id: SkinID) -> Skin {
        switch id {
        case .buddy: return BuddySkin()
        case .kitty: return KittySkin()
        case .puppy: return PuppySkin()
        case .robo: return RoboSkin()
        }
    }
}
