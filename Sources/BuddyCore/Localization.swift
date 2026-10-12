import Foundation

public enum Language: String, CaseIterable {
    case system, en, fa
}

public enum L10nKey: String, CaseIterable {
    // speech bubble
    case finishedTitle, finishedDetail, permissionTitle, permissionDetail, attentionTitle, manyTitle, knockWord
    // menu bar
    case menuSettings, menuTestKnock, menuSendHome, menuMute, menuQuit
    // settings
    case settingsTitle, sectionCharacter, sectionBehavior, sectionLanguage, sectionAgents
    case skinBuddy, skinKitty, skinPuppy, skinRobo
    case mischief, mischiefCalm, mischiefPlayful, mischiefNaughty, mischiefHint
    case size, sound, testKnock, launchAtLogin, languageSystem, quietWhenWatching, quietHint, menuWaiting
    case connected, notConnected, connect, disconnect, toolNotFound, codexTrustHint, otherAgentsHint
    // updates
    case sectionUpdates, menuCheckUpdates, menuInstallUpdate, updatesAuto, updateVersion, updateUpToDate
    case updateAvailable, updateChecking, updateInstalling, updateFailed, checkNow, installNow
}

/// Strings in English and Persian. `{agent}` and `{n}` are placeholders.
public struct L10n {
    public let language: Language   // always .en or .fa

    public init(_ preference: Language, preferred: [String] = Locale.preferredLanguages) {
        switch preference {
        case .en, .fa: language = preference
        case .system: language = (preferred.first ?? "en").hasPrefix("fa") ? .fa : .en
        }
    }

    public var isRTL: Bool { language == .fa }

    public func callAsFunction(_ key: L10nKey) -> String {
        let pair = Self.table[key] ?? (key.rawValue, key.rawValue)
        return language == .fa ? pair.fa : pair.en
    }

    public func format(_ key: L10nKey, agent: String = "", n: Int = 0, v: String = "") -> String {
        self(key).replacingOccurrences(of: "{agent}", with: agent).replacingOccurrences(of: "{n}", with: number(n))
            .replacingOccurrences(of: "{v}", with: v)
    }

    public func number(_ n: Int) -> String {
        guard language == .fa else { return String(n) }
        return String(String(n).map { c in c.wholeNumberValue.map { Character(UnicodeScalar(0x06F0 + $0)!) } ?? c })
    }

    /// The quiet tag above the buddy's head, e.g. "✓ my-app" or "✓ api +2".
    public func hint(for entries: [Waiting]) -> String? {
        guard let first = entries.first else { return nil }
        var text = "✓ " + (first.project.isEmpty ? first.agent : first.project)
        if entries.count > 1 { text += " +" + number(entries.count - 1) }
        return text
    }

    /// Speech bubble text for whoever is waiting.
    public func bubble(for entries: [Waiting]) -> (title: String, subtitle: String) {
        if entries.count > 1 {
            return (format(.manyTitle, n: entries.count), entries.map { $0.project.isEmpty ? $0.agent : $0.project }.joined(separator: " · "))
        }
        guard let w = entries.first else { return ("", "") }
        let title: String
        var detail: String
        switch w.kind {
        case .needsPermission:
            title = format(.permissionTitle, agent: w.agent)
            detail = self(.permissionDetail)
        case .needsAttention(let message):
            title = format(.attentionTitle, agent: w.agent)
            detail = message.isEmpty ? self(.finishedDetail) : message
        default:
            title = format(.finishedTitle, agent: w.agent)
            detail = self(.finishedDetail)
        }
        if !w.project.isEmpty { detail += " · \(w.project)" }
        return (title, detail)
    }

    static let table: [L10nKey: (en: String, fa: String)] = [
        .finishedTitle: ("{agent} is done! ✨", "کار {agent} تموم شد! ✨"),
        .finishedDetail: ("waiting for you 👀", "منتظرته 👀"),
        .permissionTitle: ("{agent} needs your OK! 🙋", "{agent} اجازه می‌خواد! 🙋"),
        .permissionDetail: ("come take a look", "یه سر بزن"),
        .attentionTitle: ("{agent} needs you! 👋", "{agent} کارت داره! 👋"),
        .manyTitle: ("{n} agents are waiting! 👀", "{n} تا ایجنت منتظرتن! 👀"),
        .knockWord: ("Knock!", "تق!"),

        .menuSettings: ("Settings…", "تنظیمات…"),
        .menuTestKnock: ("Knock (test)", "در بزن (تست)"),
        .menuSendHome: ("Back to your spot", "برگرد سر جات"),
        .menuMute: ("Mute", "بی‌صدا"),
        .menuQuit: ("Quit", "خروج"),

        .settingsTitle: ("Buddy Settings", "تنظیمات رفیق"),
        .sectionCharacter: ("Character", "شخصیت"),
        .sectionBehavior: ("Behavior", "رفتار"),
        .sectionLanguage: ("Language", "زبان"),
        .sectionAgents: ("Agents", "ایجنت‌ها"),
        .skinBuddy: ("Buddy", "آدمک"),
        .skinKitty: ("Kitty", "گربه"),
        .skinPuppy: ("Puppy", "توله‌سگ"),
        .skinRobo: ("Robo", "ربات"),
        .mischief: ("Mischief", "شیطونی"),
        .mischiefCalm: ("Calm", "آروم"),
        .mischiefPlayful: ("Playful", "بازیگوش"),
        .mischiefNaughty: ("Naughty", "شیطون"),
        .mischiefHint: ("Playful and Naughty buddies walk around, dance and chase your cursor. Drag them around — they fall back to the floor.",
                        "بازیگوش و شیطون راه می‌رن، می‌رقصن و دنبال موس می‌کنن. می‌تونی بلندش کنی و ولش کنی — می‌افته پایین."),
        .size: ("Size", "اندازه"),
        .sound: ("Knock sound", "صدای در زدن"),
        .testKnock: ("Try a knock", "امتحان کن"),
        .launchAtLogin: ("Open at login", "با روشن شدن مک باز شه"),
        .languageSystem: ("System", "زبان سیستم"),
        .quietWhenWatching: ("Don't knock if I'm already in the Claude / Codex app", "اگه تو خود اپ Claude یا Codex هستم در نزن"),
        .quietHint: ("Only for the agent's own app (sessions in Terminal or an editor always get a knock). It shows a small hint above the buddy instead; if you walk away, it knocks when the agent reminds you.",
                     "فقط برای خود اپ ایجنت (سشن‌های داخل ترمینال یا ادیتور همیشه در می‌زنن). به جاش یه نشونه‌ی کوچیک بالای سر رفیق میاد؛ اگه از پشت سیستم بلند شی، با یادآوری ایجنت میاد در می‌زنه."),
        .menuWaiting: ("Waiting for you", "منتظرتن"),

        .connected: ("Connected", "وصله"),
        .notConnected: ("Not connected", "وصل نیست"),
        .connect: ("Connect", "وصل کن"),
        .disconnect: ("Disconnect", "قطع کن"),
        .toolNotFound: ("not found on this Mac", "روی این مک پیدا نشد"),
        .codexTrustHint: ("After connecting, run /hooks in Codex once and trust the buddy hooks.",
                          "بعد از وصل کردن، یه بار تو Codex دستور /hooks رو بزن و هوک‌های رفیق رو تأیید کن."),
        .sectionUpdates: ("Updates", "به‌روزرسانی"),
        .menuCheckUpdates: ("Check for Updates…", "بررسی به‌روزرسانی…"),
        .menuInstallUpdate: ("⬆︎ Update to {v}", "⬆︎ به‌روزرسانی به {v}"),
        .updatesAuto: ("Install updates automatically", "به‌روزرسانی‌ها خودکار نصب بشن"),
        .updateVersion: ("Version {v}", "نسخه‌ی {v}"),
        .updateUpToDate: ("Up to date ({v})", "آخرین نسخه رو داری ({v})"),
        .updateAvailable: ("Version {v} is available", "نسخه‌ی {v} اومده"),
        .updateChecking: ("Checking…", "در حال بررسی…"),
        .updateInstalling: ("Downloading and installing…", "در حال دانلود و نصب…"),
        .updateFailed: ("Update failed: {v}", "به‌روزرسانی نشد: {v}"),
        .checkNow: ("Check now", "الان چک کن"),
        .installNow: ("Install & restart", "نصب و اجرای دوباره"),
        .otherAgentsHint: ("Any other tool can call:  ~/.claude-buddy/notify.sh <name> done",
                           "هر ابزار دیگه‌ای هم می‌تونه صدا بزنه:  ~/.claude-buddy/notify.sh <name> done"),
    ]
}
