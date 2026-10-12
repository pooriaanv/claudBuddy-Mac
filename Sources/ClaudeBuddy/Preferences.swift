import BuddyCore
import Foundation

enum BuddyPaths {
    static let home = FileManager.default.homeDirectoryForCurrentUser
    static let root = home.appendingPathComponent(".claude-buddy", isDirectory: true)
    static let inbox = root.appendingPathComponent("inbox", isDirectory: true)
    /// Exists while the buddy is knocking; lets notify.sh skip "dismiss" events cheaply.
    static let activeMarker = root.appendingPathComponent("active")
    static let notifyScript = root.appendingPathComponent("notify.sh")

    /// Copies the bundled notify.sh to ~/.claude-buddy/ (where agent hooks call it), so a downloaded app works on its own.
    static func installNotifyScript() {
        guard let bundled = Bundle.main.url(forResource: "notify", withExtension: "sh"),
              let data = try? Data(contentsOf: bundled) else { return }
        let fm = FileManager.default
        if (try? Data(contentsOf: notifyScript)) == data { return }
        try? fm.createDirectory(at: root, withIntermediateDirectories: true)
        try? data.write(to: notifyScript, options: .atomic)
        try? fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: notifyScript.path)
    }

    static func setActive(_ on: Bool) {
        if on { FileManager.default.createFile(atPath: activeMarker.path, contents: Data()) }
        else { try? FileManager.default.removeItem(at: activeMarker) }
    }
}

/// User settings, persisted in UserDefaults.
final class Preferences: ObservableObject {
    private let defaults = UserDefaults.standard

    @Published var skin: SkinID { didSet { defaults.set(skin.rawValue, forKey: "skin") } }
    @Published var language: Language { didSet { defaults.set(language.rawValue, forKey: "language") } }
    @Published var mischief: Mischief { didSet { defaults.set(mischief.rawValue, forKey: "mischief") } }
    @Published var soundOn: Bool { didSet { defaults.set(soundOn, forKey: "soundOn") } }
    /// Width of the buddy window while on the desktop, in points.
    @Published var size: Double { didSet { defaults.set(size, forKey: "size") } }
    /// Don't knock for a session whose app you're already looking at.
    @Published var quietWhenWatching: Bool { didSet { defaults.set(quietWhenWatching, forKey: "quietWhenWatching") } }

    init() {
        skin = SkinID(rawValue: defaults.string(forKey: "skin") ?? "") ?? .buddy
        language = Language(rawValue: defaults.string(forKey: "language") ?? "") ?? .system
        mischief = Mischief(rawValue: defaults.string(forKey: "mischief") ?? "") ?? .playful
        soundOn = defaults.object(forKey: "soundOn") as? Bool ?? !defaults.bool(forKey: "muted")
        size = defaults.object(forKey: "size") as? Double ?? 150
        quietWhenWatching = defaults.object(forKey: "quietWhenWatching") as? Bool ?? true
    }

    var l10n: L10n { L10n(language) }
}
