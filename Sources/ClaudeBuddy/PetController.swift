import AppKit
import BuddyCore
import QuartzCore

/// Owns the buddy's window: living on the desktop floor (walking, being carried, falling)
/// and coming up to the glass to knock. Runs one frame clock whose rate follows what's happening.
final class PetController {
    let model = SceneModel()
    /// Clicked while knocking.
    var onDismissRequested: (() -> Void)?
    /// Clicked while on the desktop (acknowledges the hint).
    var onPetted: (() -> Void)?
    /// Quiet tag shown above the head while on the desktop.
    var hint: String?

    private let prefs: Preferences
    private let brain = Brain()
    private let sound = KnockSound()
    private var panel: PetPanel!
    private var clock: Timer?
    private var clockFPS = 0.0
    private var lastTick = CACurrentMediaTime()

    private(set) var mode: PetMode = .idle
    private var centerX: CGFloat
    private var dragging = false
    private var falling = false
    private var fallSpeed: CGFloat = 0
    private var swing = 0.0
    private var lastDragX: CGFloat = 0
    private var hearts: [Double] = []
    private var postures = PostureTracker()
    /// Smoothed walking direction, so turning around takes a moment instead of snapping.
    private var facing = 1.0
    private var lastPose: Pose?
    private var lastMouse = NSPoint.zero
    private var mouseMovedAt = 0.0

    private var alertStart = 0.0
    private var hits: [Double] = []
    private var nextHit = 0
    private var bubbleText: (title: String, subtitle: String)?

    private struct FrameAnimation {
        var from: NSRect, to: NSRect, start: Double, duration: Double, overshoot: Bool, hop: CGFloat
        var done: () -> Void
    }
    private var animation: FrameAnimation?

    init(prefs: Preferences) {
        self.prefs = prefs
        let saved = UserDefaults.standard.object(forKey: "petX") as? Double
        centerX = CGFloat(saved ?? Double((NSScreen.main?.visibleFrame.maxX ?? 1200) - 120))
    }

    func start() {
        model.skin = prefs.skin
        panel = PetPanel(frame: idleFrame())
        let host = PetHostView(rootView: SceneView(model: model))
        host.onClick = { [weak self] in self?.clicked() }
        host.canDrag = { [weak self] in self?.mode == .idle }
        host.onDragBegan = { [weak self] in self?.dragBegan() }
        host.onDragMoved = { [weak self] p, grab in self?.dragMoved(to: p, grab: grab) }
        host.onDragEnded = { [weak self] in self?.dragEnded() }
        panel.contentView = host
        panel.orderFrontRegardless()
        brain.settle(at: now)
        tick()
        NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification,
                                               object: nil, queue: .main) { [weak self] _ in self?.relayout() }
    }

    /// Size or screens changed.
    func relayout() {
        model.skin = prefs.skin
        guard mode == .idle, !dragging else { return }
        falling = false
        panel.setFrame(idleFrame(), display: true)
    }

    // MARK: knocking

    func knock(title: String, subtitle: String) {
        bubbleText = (title, subtitle)
        if mode == .alert || mode == .approaching {
            hits = Knocking.schedule(from: now - alertStart + 0.5)   // someone new: knock again soon
            nextHit = 0
            return
        }
        dragging = false
        falling = false
        brain.settle(at: now)
        mode = .approaching
        alertStart = now
        hits = Knocking.schedule(from: 1.0)
        nextHit = 0
        panel.level = .statusBar
        panel.orderFrontRegardless()
        animate(to: alertFrame(), duration: 0.85, overshoot: true, hop: 80) { [weak self] in self?.mode = .alert }
    }

    func updateBubble(title: String, subtitle: String) { bubbleText = (title, subtitle) }

    func goHome() {
        guard mode == .alert || mode == .approaching else { return }
        mode = .leaving
        sound.release()
        animate(to: idleFrame(), duration: 0.6, overshoot: false, hop: 40) { [weak self] in
            guard let self else { return }
            self.panel.level = desktopLevel
            self.mode = .idle
            self.brain.land(at: self.now)
        }
    }

    // MARK: input

    private func clicked() {
        switch mode {
        case .alert, .approaching:
            onDismissRequested?()
        case .idle:
            hearts.append(now)
            brain.poke(at: now)
            onPetted?()
        case .leaving:
            break
        }
        tick()
    }

    private func dragBegan() {
        dragging = true
        falling = false
        swing = 0
        lastDragX = NSEvent.mouseLocation.x
        brain.pickUp(at: now)
    }

    private func dragMoved(to p: NSPoint, grab: NSPoint) {
        panel.setFrameOrigin(NSPoint(x: p.x - grab.x, y: p.y - grab.y))
        let dx = Double(p.x - lastDragX)
        lastDragX = p.x
        swing = max(-28, min(28, swing * 0.8 - dx * 0.9))
    }

    private func dragEnded() {
        dragging = false
        centerX = panel.frame.midX
        UserDefaults.standard.set(Double(centerX), forKey: "petX")
        if panel.frame.minY > idleFrame().minY + 2 {
            falling = true
            fallSpeed = 0
            brain.drop(at: now)
        } else {
            brain.land(at: now)
        }
    }

    // MARK: frame clock

    private var now: Double { CACurrentMediaTime() }

    private func tick() {
        let t = now
        let dt = min(0.1, t - lastTick)
        lastTick = t

        if let a = animation { stepAnimation(a, t) }

        if mode == .idle && !dragging && animation == nil {
            if falling { stepFall(dt) } else { stepWalk(dt, t) }
        }
        if mode == .alert || mode == .approaching { playDueKnocks(t) }
        if !dragging { swing *= 0.9 }
        hearts.removeAll { t - $0 > 1.6 }

        model.scene = buildScene(t, dt: dt)
        scheduleClock(desiredFPS())
    }

    private func stepAnimation(_ a: FrameAnimation, _ t: Double) {
        let x = min(1, (t - a.start) / a.duration)
        let k: Double
        if a.overshoot {
            let c1 = 1.4, c3 = c1 + 1
            k = 1 + c3 * pow(x - 1, 3) + c1 * pow(x - 1, 2)
        } else {
            k = x < 0.5 ? 4 * x * x * x : 1 - pow(-2 * x + 2, 3) / 2
        }
        let up = CGFloat(sin(x * .pi)) * a.hop
        let r = NSRect(x: a.from.minX + (a.to.minX - a.from.minX) * k,
                       y: a.from.minY + (a.to.minY - a.from.minY) * k + up,
                       width: max(40, a.from.width + (a.to.width - a.from.width) * k),
                       height: max(54, a.from.height + (a.to.height - a.from.height) * k))
        panel.setFrame(r, display: true)
        if x >= 1 {
            animation = nil
            panel.setFrame(a.to, display: true)
            a.done()
        }
    }

    private func stepFall(_ dt: Double) {
        fallSpeed += 2600 * CGFloat(dt)
        var f = panel.frame
        let floor = idleFrame().minY
        f.origin.y -= fallSpeed * CGFloat(dt)
        if f.origin.y <= floor {
            f.origin.y = floor
            falling = false
            brain.land(at: now)
        }
        panel.setFrameOrigin(f.origin)
    }

    private func stepWalk(_ dt: Double, _ t: Double) {
        let frame = panel.frame
        let vf = floorScreen().visibleFrame
        let mouse = NSEvent.mouseLocation
        if mouse != lastMouse {
            lastMouse = mouse
            mouseMovedAt = t
        }
        let head = headCenter(frame)
        let ctx = BrainContext(now: t, x: Double(centerX),
                               minX: Double(vf.minX + frame.width / 2), maxX: Double(vf.maxX - frame.width / 2),
                               mouse: CGPoint(x: mouse.x - head.x, y: mouse.y - head.y),
                               mouseMovedAgo: t - mouseMovedAt, userIdle: Focus.userIdleSeconds(),
                               mischief: prefs.mischief)
        let v = brain.tick(ctx)
        if v != 0 {
            centerX = min(vf.maxX - frame.width / 2, max(vf.minX + frame.width / 2, centerX + CGFloat(v * dt)))
            panel.setFrameOrigin(NSPoint(x: centerX - frame.width / 2, y: frame.minY))
            UserDefaults.standard.set(Double(centerX), forKey: "petX")
        }
    }

    private func playDueKnocks(_ t: Double) {
        let e = t - alertStart
        while nextHit < hits.count && hits[nextHit] <= e {
            if prefs.soundOn && e - hits[nextHit] < 0.1 { sound.play(SkinCatalog.skin(prefs.skin).tone) }
            nextHit += 1
        }
    }

    private func buildScene(_ t: Double, dt: Double) -> PetScene {
        let turnStep = dt / 0.3 * 2
        facing += max(-turnStep, min(turnStep, brain.direction - facing))
        let target = Animator.targetPosture(mode: mode, activity: brain.activity)
        postures.update(target: target.0, duration: target.1, now: t)

        var input = AnimationInput(t: t)
        input.mode = mode
        input.activity = brain.activity
        input.activityElapsed = brain.elapsed(at: t)
        input.direction = facing
        input.posture = postures.state(at: t)
        input.alertElapsed = t - alertStart
        input.knockHits = hits
        input.heartAges = hearts.map { t - $0 }
        input.swing = swing
        if mode == .idle, let frame = panel?.frame {
            let head = headCenter(frame)
            let m = NSEvent.mouseLocation
            let dx = m.x - head.x, dy = m.y - head.y
            if hypot(dx, dy) < 450 {
                input.lookTarget = CGPoint(x: max(-1, min(1, dx / 220)), y: max(-1, min(1, -dy / 220)))
            }
        }
        var scene = Animator.scene(input)
        // Ease between activities so arms, height and lean never snap (knocking stays crisp).
        if mode == .idle, let last = lastPose {
            scene.pose = last.eased(toward: scene.pose, 1 - exp(-dt / 0.07))
        }
        lastPose = scene.pose
        let l10n = prefs.l10n
        scene.knockText = l10n(.knockWord)
        if mode == .idle { scene.hint = hint }
        if let b = bubbleText, mode == .alert || mode == .approaching {
            scene.bubble = Bubble(title: b.title, subtitle: b.subtitle, rtl: l10n.isRTL,
                                  appear: smooth((t - alertStart - 0.75) / 0.25))
        }
        return scene
    }

    private func desiredFPS() -> Double {
        if animation != nil || mode != .idle || dragging || falling { return 60 }
        if !hearts.isEmpty { return 30 }
        switch brain.activity {
        case .walk, .jump, .dance, .wave, .yawn, .dangle, .fall: return 30
        case .sleep: return 8
        case .sit, .lookAround: return 12
        }
    }

    private func scheduleClock(_ fps: Double) {
        guard fps != clockFPS else { return }
        if Self.debug { FileHandle.standardError.write("fps \(clockFPS) → \(fps)  mode=\(mode) activity=\(brain.activity)\n".data(using: .utf8)!) }
        clockFPS = fps
        clock?.invalidate()
        clock = Timer.scheduledTimer(withTimeInterval: 1 / fps, repeats: true) { [weak self] _ in self?.tick() }
        clock?.tolerance = 0.2 / fps
    }

    // MARK: geometry

    private func animate(to target: NSRect, duration: Double, overshoot: Bool, hop: CGFloat, done: @escaping () -> Void) {
        animation = FrameAnimation(from: panel.frame, to: target, start: now, duration: duration,
                                   overshoot: overshoot, hop: hop, done: done)
        scheduleClock(60)
    }

    private func floorScreen() -> NSScreen {
        NSScreen.screens.first { $0.frame.minX <= centerX && centerX < $0.frame.maxX } ?? NSScreen.main ?? NSScreen.screens[0]
    }

    /// On the floor (just above the Dock), at `centerX`.
    private func idleFrame() -> NSRect {
        let w = CGFloat(prefs.size)
        let h = w * SceneRenderer.design.height / SceneRenderer.design.width
        let vf = floorScreen().visibleFrame
        let x = min(vf.maxX - w / 2, max(vf.minX + w / 2, centerX))
        return NSRect(x: x - w / 2, y: vf.minY - h * 0.035, width: w, height: h)
    }

    /// Big and centered on the screen with the cursor — right up against the glass.
    private func alertFrame() -> NSRect {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main ?? NSScreen.screens[0]
        let vf = screen.visibleFrame
        let h = min(vf.height * 0.82, 720)
        let w = h * SceneRenderer.design.width / SceneRenderer.design.height
        return NSRect(x: vf.midX - w / 2, y: vf.midY - h / 2, width: w, height: h)
    }

    private func headCenter(_ frame: NSRect) -> CGPoint {
        CGPoint(x: frame.midX, y: frame.maxY - frame.height * 160 / 320)
    }

    /// `BUDDY_DEBUG=1` logs frame-rate changes to stderr.
    private static let debug = ProcessInfo.processInfo.environment["BUDDY_DEBUG"] != nil

}
