import Foundation

/// Something an AI coding agent told the buddy, normalized across tools.
public struct AgentEvent: Equatable {
    public enum Kind: Equatable {
        /// The agent finished its turn and is waiting for you.
        case finished
        /// The agent is blocked on a permission prompt.
        case needsPermission
        /// The agent wants you for some other reason (free-form message).
        case needsAttention(message: String)
        /// "Still waiting" reminder; only matters if nothing else is pending.
        case idleReminder
        /// You're back at it (prompt submitted, tool ran, session ended).
        case resumed
    }

    public var kind: Kind
    /// Display name, e.g. "Claude" or "Codex".
    public var agent: String
    /// Unique per agent session; used to track who is waiting.
    public var session: String
    /// Folder name of the agent's working directory.
    public var project: String
    /// The app the session runs in (e.g. /Applications/Claude.app, Terminal.app), when known.
    public var host: String?

    public init(kind: Kind, agent: String, session: String, project: String, host: String? = nil) {
        self.kind = kind
        self.agent = agent
        self.session = session
        self.project = project
        self.host = host
    }
}

/// Translates one tool's notifications into `AgentEvent`s.
/// To support a new tool, add an adapter and register it in `AgentAdapters.known`.
public protocol AgentAdapter {
    /// Name used on the `notify.sh <source> <event>` command line.
    var source: String { get }
    var displayName: String { get }
    func event(named event: String, payload: [String: Any]) -> AgentEvent?
}

/// Claude Code and Codex share the same hook shape (`session_id`, `cwd`, `hook_event_name`),
/// so one adapter serves both. It also understands Codex's legacy `notify` payload.
public struct HookAgentAdapter: AgentAdapter {
    public let source: String
    public let displayName: String

    public init(source: String, displayName: String) {
        self.source = source
        self.displayName = displayName
    }

    public func event(named event: String, payload: [String: Any]) -> AgentEvent? {
        let name = (event.isEmpty || event == "auto") ? Self.inferredEvent(payload) : event
        guard let kind = Self.kind(for: name, payload: payload) else { return nil }
        return AgentEvent(kind: kind, agent: displayName,
                          session: "\(source):\(Self.session(payload))", project: Self.project(payload))
    }

    static func inferredEvent(_ p: [String: Any]) -> String {
        (p["hook_event_name"] as? String) ?? (p["type"] as? String) ?? ""
    }

    static func kind(for name: String, payload: [String: Any]) -> AgentEvent.Kind? {
        switch name {
        case "done", "Stop", "agent-turn-complete":
            return .finished
        case "permission", "PermissionRequest", "approval-requested":
            return .needsPermission
        case "waiting", "Notification":
            let message = (payload["message"] as? String) ?? ""
            let lower = message.lowercased()
            if lower.contains("permission") || lower.contains("approv") { return .needsPermission }
            if lower.contains("waiting for your input") || lower.contains("idle") { return .idleReminder }
            return .needsAttention(message: message)
        case "dismiss", "UserPromptSubmit", "PostToolUse", "SessionEnd":
            return .resumed
        default:
            return nil
        }
    }

    static func session(_ p: [String: Any]) -> String {
        for key in ["session_id", "thread-id", "thread_id", "session"] {
            if let s = p[key] as? String, !s.isEmpty { return s }
        }
        return "default"
    }

    static func project(_ p: [String: Any]) -> String {
        if let name = p["project"] as? String, !name.isEmpty { return name }
        if let cwd = p["cwd"] as? String, !cwd.isEmpty { return (cwd as NSString).lastPathComponent }
        return ""
    }
}

/// Any other tool: `notify.sh <name> done '{"message": "...", "project": "..."}'`.
public struct GenericAgentAdapter: AgentAdapter {
    public let source: String
    public var displayName: String { source.prefix(1).uppercased() + source.dropFirst() }

    public init(source: String) { self.source = source }

    public func event(named event: String, payload: [String: Any]) -> AgentEvent? {
        HookAgentAdapter(source: source, displayName: displayName).event(named: event, payload: payload)
    }
}

/// Apps that are nothing but an AI agent's UI. Being in front of one means you're looking at the agent.
/// Terminals and editors host far more than the agent, so being in them doesn't count as watching it.
public enum AgentApps {
    public static let bundleIDs: Set<String> = ["com.anthropic.claudefordesktop", "com.openai.codex", "com.openai.chat"]

    public static func isDedicated(bundleID: String?, appName: String) -> Bool {
        if let id = bundleID, bundleIDs.contains(id) { return true }
        let name = appName.lowercased()
        return name.hasPrefix("claude") || name.hasPrefix("codex")
    }
}

public enum AgentAdapters {
    public static let known: [AgentAdapter] = [
        HookAgentAdapter(source: "claude", displayName: "Claude"),
        HookAgentAdapter(source: "codex", displayName: "Codex"),
    ]

    public static func adapter(for source: String) -> AgentAdapter {
        let key = source.lowercased()
        return known.first { $0.source == key } ?? GenericAgentAdapter(source: key.isEmpty ? "agent" : key)
    }

    public static func event(from message: InboxMessage) -> AgentEvent? {
        var e = adapter(for: message.source).event(named: message.event, payload: message.payload)
        e?.host = message.meta["host"]
        return e
    }
}
