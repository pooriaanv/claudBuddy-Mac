import CoreGraphics
import Testing
@testable import BuddyCore

@Suite struct BrainTests {
    /// Runs the brain for `seconds` at 20 ticks/s, moving x by the returned velocity.
    func run(_ brain: Brain, seconds: Double, mischief: Mischief, x: inout Double,
             userIdle: (Double) -> Double = { _ in 0 }, visit: (Activity) -> Void = { _ in }) {
        var now = 0.0
        while now < seconds {
            let v = brain.tick(BrainContext(now: now, x: x, minX: 100, maxX: 1500,
                                            userIdle: userIdle(now), mischief: mischief))
            x = min(1500, max(100, x + v * 0.05))
            visit(brain.activity)
            now += 0.05
        }
    }

    @Test func calmBuddiesNeverWalk() {
        for seed in 1...20 {
            let brain = Brain(seed: UInt64(seed))
            var x = 800.0
            var walked = false
            run(brain, seconds: 300, mischief: .calm, x: &x) { if $0 == .walk { walked = true } }
            #expect(!walked)
            #expect(x == 800)
        }
    }

    @Test func playfulBuddiesWanderAndStayOnScreen() {
        let brain = Brain(seed: 7)
        var x = 800.0
        var seen = Set<Activity>()
        run(brain, seconds: 600, mischief: .playful, x: &x) { seen.insert($0) }
        #expect(seen.contains(.walk))
        #expect(seen.contains(.sit))
        #expect((100...1500).contains(x))
    }

    @Test func sleepsWhenHumanIsAwayAndWakesWithAYawn() {
        let brain = Brain(seed: 3)
        var x = 800.0
        run(brain, seconds: 200, mischief: .playful, x: &x, userIdle: { $0 })
        #expect(brain.activity == .sleep)
        brain.tick(BrainContext(now: 201, x: x, minX: 100, maxX: 1500, userIdle: 0))
        #expect(brain.activity == .yawn)
    }

    @Test func wavesWhenTheCursorComesClose() {
        let brain = Brain(seed: 1)
        brain.tick(BrainContext(now: 0, x: 500, minX: 0, maxX: 1000,
                                mouse: CGPoint(x: 40, y: 30), mouseMovedAgo: 0.1))
        #expect(brain.activity == .wave)
    }

    @Test func pokingASleepyBuddyWakesIt() {
        let brain = Brain(seed: 1)
        var x = 800.0
        run(brain, seconds: 200, mischief: .calm, x: &x, userIdle: { $0 })
        brain.poke(at: 200)
        #expect(brain.activity == .yawn)
        brain.poke(at: 203)
        #expect(brain.activity == .jump)
    }

    @Test func carriedBuddyIgnoresTheBrain() {
        let brain = Brain(seed: 1)
        brain.pickUp(at: 0)
        #expect(brain.tick(BrainContext(now: 50, x: 0, minX: 0, maxX: 10, userIdle: 999)) == 0)
        #expect(brain.activity == .dangle)
    }
}

@Suite struct AnimatorTests {
    @Test func knockingRaisesTheArmAndPressesTheGlass() {
        var input = AnimationInput(t: 100)
        input.mode = .alert
        input.knockHits = Knocking.schedule(from: 1.0)
        input.alertElapsed = 1.0   // exactly on the first hit
        let s = Animator.scene(input)
        #expect(s.pose.reach > 0.9)
        #expect(s.pose.rightArmInFront)
        #expect(s.pose.press > 2)
        #expect(s.knockAges == [0])
    }

    @Test func sleepingClosesEyes() {
        var input = AnimationInput(t: 5)
        input.activity = .sleep
        let s = Animator.scene(input)
        #expect(s.sleeping)
        #expect(s.pose.eyeOpen == 0)
        #expect(s.pose.mood == .sleepy)
    }

    @Test func walkingSteps() {
        var input = AnimationInput(t: 5)
        input.activity = .walk
        input.activityElapsed = 0.3
        input.direction = -1
        let p = Animator.scene(input).pose
        #expect(p.stepPhase != nil)
        #expect(p.lean < 0)
        #expect(p.footLift(left: true) > 0 || p.footLift(left: false) > 0)
    }

    @Test func pattingMakesItHappy() {
        var input = AnimationInput(t: 5)
        input.heartAges = [0.3]
        #expect(Animator.scene(input).pose.mood == .happy)
    }

    @Test func posturesFollowActivities() {
        func posture(_ a: Activity, e: Double = 2) -> Pose {
            var input = AnimationInput(t: 5)
            input.activity = a
            input.activityElapsed = e
            return Animator.scene(input).pose
        }
        #expect(posture(.sit).posture == .sit)
        #expect(posture(.walk).posture == .stand)
        #expect(posture(.sleep).posture == .lie)
        #expect(posture(.yawn).posture == .stretch)
        #expect(posture(.dangle).airborne)
        #expect(posture(.walk, e: 0).postureBlend == 0)   // starts blending from sitting
    }

    @Test func knockingTurnsToFaceTheViewer() {
        var input = AnimationInput(t: 5)
        input.mode = .alert
        input.alertElapsed = 2
        input.direction = -1
        let p = Animator.scene(input).pose
        #expect(p.posture == .front && p.postureBlend == 1)
        #expect(p.facing == -1)
    }

    @Test func postureTrackerStartsFromWhereTheBodyIs() {
        var tracker = PostureTracker()
        // sitting → looking around (also sitting): no transition at all
        tracker.update(target: .sit, duration: 0.35, now: 0)
        #expect(tracker.blend(at: 0.01) == 1)
        // sit → stand → back to sit before standing finished: start from sit, not stand
        tracker.update(target: .stand, duration: 0.3, now: 1)
        tracker.update(target: .sit, duration: 0.35, now: 1.05)
        #expect(tracker.state(at: 1.05).from == .sit)
        // fully standing → lie: starts from stand
        tracker.update(target: .stand, duration: 0.3, now: 2)
        tracker.update(target: .lie, duration: 0.8, now: 3)
        #expect(tracker.state(at: 3).from == .stand)
    }

    @Test func easingRemovesSnaps() {
        var a = Pose(); a.lift = -20; a.leftArm = 150
        let b = Pose()
        let half = a.eased(toward: b, 0.5)
        #expect(half.lift == -10)
        #expect(half.leftArm == (150 + 14) / 2)
    }
}
