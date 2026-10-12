import AppKit
import BuddyCore
import SwiftUI

/// Debug renderer: `ClaudeBuddy --snapshot out.png [lang]` writes a sheet of every skin in every pose.
enum Snapshot {
    struct Shot {
        let label: String
        let input: AnimationInput
        var bubble: Bubble?
        var hint: String?
    }

    static func shots(_ l10n: L10n) -> [Shot] {
        func make(_ label: String, _ activity: Activity, e: Double = 0.3, t: Double = 10.05, _ edit: (inout AnimationInput) -> Void = { _ in }) -> Shot {
            var i = AnimationInput(t: t)
            i.activity = activity
            i.activityElapsed = e
            edit(&i)
            return Shot(label: label, input: i)
        }
        let (title, sub) = l10n.bubble(for: [Waiting(agent: "Claude", project: "my-app", kind: .finished)])
        var knock = make("knock", .sit) {
            $0.mode = .alert
            $0.knockHits = Knocking.schedule(from: 1.0)
            $0.alertElapsed = 1.27
        }
        knock.bubble = Bubble(title: title, subtitle: sub, rtl: l10n.isRTL, appear: 1)
        let turning = make("turning", .sit) {
            $0.mode = .approaching
            $0.alertElapsed = 0.22
        }
        var sit = make("sit + hint", .sit, t: 11.0)
        sit.hint = l10n.hint(for: [Waiting(agent: "Claude", project: "my-app", kind: .finished, quiet: true)])
        return [
            sit,
            make("walk →", .walk, e: 0.25) { $0.direction = 1 },
            make("walk ←", .walk, e: 0.42) { $0.direction = -1 },
            make("jump", .jump, e: 0.3),
            make("dance", .dance, e: 0.3),
            make("wave", .wave, e: 0.8),
            make("yawn", .yawn, e: 1.1),
            make("sleep", .sleep, e: 3),
            make("carried", .dangle) { $0.swing = 12 },
            make("pat", .sit, t: 11.0) { $0.heartAges = [0.45] },
            turning,
            knock,
        ]
    }

    static func render(to path: String, language: Language) {
        let l10n = L10n(language)
        let shots = shots(l10n)
        let cell = CGSize(width: 180, height: 240)
        let grid = VStack(alignment: .leading, spacing: 0) {
            ForEach(SkinID.allCases) { skin in
                HStack(spacing: 0) {
                    ForEach(Array(shots.enumerated()), id: \.offset) { _, shot in
                        VStack(spacing: 0) {
                            Canvas { ctx, size in
                                var scene = Animator.scene(shot.input)
                                scene.bubble = shot.bubble
                                scene.hint = shot.hint
                                scene.knockText = l10n(.knockWord)
                                SceneRenderer.draw(&ctx, size: size, scene: scene, skin: SkinCatalog.skin(skin))
                            }
                            .frame(width: cell.width, height: cell.height)
                            Text("\(skin.rawValue) · \(shot.label)").font(.system(size: 11)).foregroundColor(.white.opacity(0.7))
                                .padding(.bottom, 6)
                        }
                    }
                }
            }
        }
        .background(Color(white: 0.33))

        // menu-bar faces, enlarged 4×, next to the sheet
        let faces = HStack(spacing: 16) {
            ForEach(SkinID.allCases) { skin in
                Image(nsImage: AppIcon.menuBarImage(skin)).resizable().interpolation(.none).frame(width: 72, height: 72)
                Image(nsImage: AppIcon.menuBarImage(skin)).frame(width: 18, height: 18)
            }
        }
        .padding(12)
        .background(Color(white: 0.92))

        MainActor.assumeIsolated {
            let f = ImageRenderer(content: faces)
            f.scale = 2
            if let cg = f.cgImage, let png = NSBitmapImageRep(cgImage: cg).representation(using: .png, properties: [:]) {
                try? png.write(to: URL(fileURLWithPath: path.replacingOccurrences(of: ".png", with: "-menubar.png")))
            }
            let r = ImageRenderer(content: grid)
            r.scale = 1
            if let img = r.nsImage, let tiff = img.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff),
               let png = rep.representation(using: .png, properties: [:]) {
                try? png.write(to: URL(fileURLWithPath: path))
            }
        }
    }
}
