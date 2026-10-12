import Foundation

/// An agent session that is waiting for you.
public struct Waiting: Equatable {
    public var agent: String
    public var project: String
    public var kind: AgentEvent.Kind
    /// You were already looking at the agent when it finished: no knocking, just a menu-bar dot.
    public var quiet: Bool

    public init(agent: String, project: String, kind: AgentEvent.Kind, quiet: Bool = false) {
        self.agent = agent
        self.project = project
        self.kind = kind
        self.quiet = quiet
    }
}

/// Who is waiting, in arrival order. Decides when the buddy should knock, stay quiet or go home.
public struct AttentionQueue {
    public enum Change: Equatable {
        /// Someone needs you and you're not looking: come knock.
        case knock
        /// The waiting list changed; keep doing what you're doing.
        case updated
        /// Someone finished while you were watching it: note it quietly.
        case quietlyAdded
        /// Nobody left that needs a knock (quiet ones may remain): go home.
        case settle
        /// Nobody is waiting anymore.
        case empty
        case none
    }

    private var items: [String: Waiting] = [:]
    private var order: [String] = []

    public init() {}

    public var isEmpty: Bool { order.isEmpty }
    public var entries: [Waiting] { order.compactMap { items[$0] } }
    public var needsKnock: Bool { items.values.contains { !$0.quiet } }

    /// `watching`: the human is looking at this agent's window right now.
    public mutating func apply(_ event: AgentEvent, watching: Bool = false) -> Change {
        let key = event.session
        switch event.kind {
        case .resumed:
            guard items[key] != nil else { return .none }
            items[key] = nil
            order.removeAll { $0 == key }
            if order.isEmpty { return .empty }
            return needsKnock ? .updated : .settle
        case .idleReminder:
            if var existing = items[key] {
                // Finished while you watched, but you've since walked away: knock after all.
                guard existing.quiet && !watching else { return .none }
                existing.quiet = false
                items[key] = existing
                return .knock
            }
            return add(key, Waiting(agent: event.agent, project: event.project, kind: .finished), watching: watching)
        default:
            return add(key, Waiting(agent: event.agent, project: event.project, kind: event.kind), watching: watching)
        }
    }

    /// "Got it": forget the quiet ones (the buddy was clicked).
    public mutating func clearQuiet() {
        for (key, w) in items where w.quiet { items[key] = nil }
        order.removeAll { items[$0] == nil }
    }

    public mutating func clear() {
        items.removeAll()
        order.removeAll()
    }

    private mutating func add(_ key: String, _ w: Waiting, watching: Bool) -> Change {
        var w = w
        w.quiet = watching
        let wasKnocking = needsKnock
        items[key] = w
        order.removeAll { $0 == key }
        order.append(key)
        if !watching { return .knock }
        return wasKnocking ? .updated : .quietlyAdded
    }
}
