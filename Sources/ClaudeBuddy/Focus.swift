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
        guard same, userIdleSeconds() < seconds,
              let pid = NSWorkspace.shared.frontmostApplication?.processIdentifier else { return false }
        // Active isn't enough: a minimized app stays "frontmost" with nothing on screen.
        return ScreenWindows.frontmostOwner(onScreenWindows()) == pid
    }

    /// On-screen windows, front to back. Owner and bounds need no screen-recording permission (titles would).
    static func onScreenWindows() -> [WindowInfo] {
        let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID)
            as? [[String: Any]] ?? []
        return list.compactMap { w in
            guard let pid = w[kCGWindowOwnerPID as String] as? Int32,
                  let layer = w[kCGWindowLayer as String] as? Int,
                  let bounds = w[kCGWindowBounds as String] as? [String: Any],
                  let rect = CGRect(dictionaryRepresentation: bounds as CFDictionary) else { return nil }
            let alpha = w[kCGWindowAlpha as String] as? Double ?? 1
            return WindowInfo(ownerPID: pid, layer: layer, alpha: alpha, width: rect.width, height: rect.height)
        }
    }
}
