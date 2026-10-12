import AppKit
import BuddyCore

/// Is the human looking at a given app right now?
enum Focus {
    /// Seconds since the last mouse/keyboard input.
    static func userIdleSeconds() -> Double {
        let anyInput = CGEventType(rawValue: ~0) ?? .mouseMoved
        return CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: anyInput)
    }

    /// True when `host` is an agent's own app (Claude, Codex — not a terminal or editor), it's the frontmost app,
    /// and the human touched mouse/keyboard in the last few seconds.
    static func isWatching(host: String?, activeWithin seconds: Double = 15) -> Bool {
        guard let host, !host.isEmpty,
              let front = NSWorkspace.shared.frontmostApplication?.bundleURL else { return false }
        let hostURL = URL(fileURLWithPath: host)
        guard AgentApps.isDedicated(bundleID: Bundle(url: hostURL)?.bundleIdentifier,
                                    appName: hostURL.deletingPathExtension().lastPathComponent) else { return false }
        let same = front.standardizedFileURL.resolvingSymlinksInPath().path
            == URL(fileURLWithPath: host).standardizedFileURL.resolvingSymlinksInPath().path
        return same && userIdleSeconds() < seconds
    }
}
