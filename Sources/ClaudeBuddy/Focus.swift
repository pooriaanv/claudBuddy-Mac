import AppKit

/// Is the human looking at a given app right now?
enum Focus {
    /// Seconds since the last mouse/keyboard input.
    static func userIdleSeconds() -> Double {
        let anyInput = CGEventType(rawValue: ~0) ?? .mouseMoved
        return CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: anyInput)
    }

    /// True when `host` (an .app path) is the frontmost app and the human touched mouse/keyboard recently.
    static func isWatching(host: String?, activeWithin seconds: Double = 45) -> Bool {
        guard let host, !host.isEmpty,
              let front = NSWorkspace.shared.frontmostApplication?.bundleURL else { return false }
        let same = front.standardizedFileURL.resolvingSymlinksInPath().path
            == URL(fileURLWithPath: host).standardizedFileURL.resolvingSymlinksInPath().path
        return same && userIdleSeconds() < seconds
    }
}
