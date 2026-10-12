import Foundation

/// An AI coding tool the buddy can hook into. Both use the same hooks JSON shape:
/// `{"hooks": {"<Event>": [{"matcher": "...", "hooks": [{"type": "command", "command": "..."}]}]}}`.
enum AgentIntegration: String, CaseIterable, Identifiable {
    case claude, codex

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .claude: return "Claude Code"
        case .codex: return "Codex"
        }
    }

    var configURL: URL {
        switch self {
        case .claude: return BuddyPaths.home.appendingPathComponent(".claude/settings.json")
        case .codex: return BuddyPaths.home.appendingPathComponent(".codex/hooks.json")
        }
    }

    var toolDetected: Bool {
        let fm = FileManager.default
        switch self {
        case .claude:
            return fm.fileExists(atPath: BuddyPaths.home.appendingPathComponent(".claude").path)
        case .codex:
            let candidates = [BuddyPaths.home.appendingPathComponent(".codex").path,
                              "/opt/homebrew/bin/codex", "/usr/local/bin/codex"]
            return candidates.contains { fm.fileExists(atPath: $0) }
        }
    }

    /// (hook event, notify.sh event, matcher)
    var hooks: [(event: String, arg: String, matcher: String?)] {
        switch self {
        case .claude:
            return [("Stop", "done", nil), ("Notification", "waiting", nil),
                    ("UserPromptSubmit", "dismiss", nil), ("PostToolUse", "dismiss", "*")]
        case .codex:
            return [("Stop", "done", nil), ("PermissionRequest", "permission", "*"),
                    ("UserPromptSubmit", "dismiss", nil), ("PostToolUse", "dismiss", "*")]
        }
    }

    func command(_ arg: String) -> String { "\"\(BuddyPaths.notifyScript.path)\" \(rawValue) \(arg)" }

    // MARK: install / uninstall

    static let marker = ".claude-buddy/notify.sh"

    var isConnected: Bool {
        guard let root = try? Self.read(configURL), let hooks = root["hooks"] as? [String: Any] else { return false }
        return self.hooks.allSatisfy { spec in
            Self.groups(hooks[spec.event]).contains { group in
                Self.handlers(group).contains { ($0["command"] as? String ?? "").contains("notify.sh\" \(rawValue) \(spec.arg)") }
            }
        }
    }

    func connect() throws {
        try Self.mutate(configURL) { root in
            var hooks = root["hooks"] as? [String: Any] ?? [:]
            Self.strip(&hooks)
            for spec in self.hooks {
                var group: [String: Any] = ["hooks": [["type": "command", "command": command(spec.arg)]]]
                if let m = spec.matcher { group["matcher"] = m }
                hooks[spec.event] = Self.groups(hooks[spec.event]) + [group]
            }
            root["hooks"] = hooks
        }
    }

    func disconnect() throws {
        try Self.mutate(configURL) { root in
            var hooks = root["hooks"] as? [String: Any] ?? [:]
            Self.strip(&hooks)
            root["hooks"] = hooks.isEmpty ? nil : hooks
        }
    }

    // MARK: JSON helpers

    private static func groups(_ value: Any?) -> [[String: Any]] { value as? [[String: Any]] ?? [] }
    private static func handlers(_ group: [String: Any]) -> [[String: Any]] { group["hooks"] as? [[String: Any]] ?? [] }

    /// Removes every buddy handler, dropping groups that only contained buddy handlers.
    private static func strip(_ hooks: inout [String: Any]) {
        for (event, value) in hooks {
            let cleaned: [[String: Any]] = groups(value).compactMap { group in
                let before = handlers(group)
                let after = before.filter { !($0["command"] as? String ?? "").contains(marker) }
                if after.count == before.count { return group }
                if after.isEmpty { return nil }
                var g = group
                g["hooks"] = after
                return g
            }
            hooks[event] = cleaned.isEmpty ? nil : cleaned
        }
    }

    private static func read(_ url: URL) throws -> [String: Any] {
        guard let data = try? Data(contentsOf: url), !data.isEmpty else { return [:] }
        guard let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw CocoaError(.fileReadCorruptFile, userInfo: [NSFilePathErrorKey: url.path])
        }
        return obj
    }

    /// Read-modify-write with a one-time backup of the original file.
    private static func mutate(_ url: URL, _ body: (inout [String: Any]) -> Void) throws {
        let fm = FileManager.default
        var root = try read(url)
        let backup = url.appendingPathExtension("buddy-backup")
        if fm.fileExists(atPath: url.path) && !fm.fileExists(atPath: backup.path) {
            try fm.copyItem(at: url, to: backup)
        }
        body(&root)
        try fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let data = try JSONSerialization.data(withJSONObject: root, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
        try data.write(to: url, options: .atomic)
    }
}

/// "Open at login" via a per-user LaunchAgent.
enum LaunchAtLogin {
    static let label = "com.pooria.claudebuddy"
    static var plistURL: URL { BuddyPaths.home.appendingPathComponent("Library/LaunchAgents/\(label).plist") }

    static var isEnabled: Bool { FileManager.default.fileExists(atPath: plistURL.path) }

    static func set(_ on: Bool) throws {
        if !on {
            try? FileManager.default.removeItem(at: plistURL)
            return
        }
        let plist: [String: Any] = [
            "Label": label,
            "ProgramArguments": ["/usr/bin/open", "-g", "-b", label],
            "RunAtLoad": true,
        ]
        let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        try FileManager.default.createDirectory(at: plistURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: plistURL, options: .atomic)
    }
}
