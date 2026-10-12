import Testing
@testable import BuddyCore

@Suite struct AgentEventTests {
    @Test func claudeStopHookMeansFinished() {
        let msg = InboxMessage.parse("claude done\n{\"session_id\":\"s1\",\"cwd\":\"/Users/me/Work/shop\"}")
        let e = AgentAdapters.event(from: msg)
        #expect(e == AgentEvent(kind: .finished, agent: "Claude", session: "claude:s1", project: "shop"))
    }

    @Test func legacySingleWordHeaderIsClaude() {
        let msg = InboxMessage.parse("dismiss\n{\"session_id\":\"s1\"}")
        #expect(msg.source == "claude")
        #expect(AgentAdapters.event(from: msg)?.kind == .resumed)
    }

    @Test func codexHookEvents() {
        let stop = AgentAdapters.event(from: InboxMessage.parse("codex done\n{\"session_id\":\"x\",\"cwd\":\"/a/api\"}"))
        #expect(stop == AgentEvent(kind: .finished, agent: "Codex", session: "codex:x", project: "api"))
        let perm = AgentAdapters.event(from: InboxMessage.parse("codex permission\n{\"session_id\":\"x\"}"))
        #expect(perm?.kind == .needsPermission)
    }

    @Test func codexLegacyNotifyPayloadIsInferred() {
        let msg = InboxMessage.parse("codex auto\n{\"type\":\"agent-turn-complete\",\"thread-id\":\"t9\",\"cwd\":\"/p/web\"}")
        let e = AgentAdapters.event(from: msg)
        #expect(e == AgentEvent(kind: .finished, agent: "Codex", session: "codex:t9", project: "web"))
    }

    @Test func notificationMessagesAreClassified() {
        func kind(_ message: String) -> AgentEvent.Kind? {
            HookAgentAdapter(source: "claude", displayName: "Claude").event(named: "waiting", payload: ["message": message])?.kind
        }
        #expect(kind("Claude needs your permission to use Bash") == .needsPermission)
        #expect(kind("Claude is waiting for your input") == .idleReminder)
        #expect(kind("Build broke") == .needsAttention(message: "Build broke"))
    }

    @Test func unknownToolsGetAGenericAdapter() {
        let e = AgentAdapters.event(from: InboxMessage.parse("gemini done\n{\"project\":\"blog\"}"))
        #expect(e == AgentEvent(kind: .finished, agent: "Gemini", session: "gemini:default", project: "blog"))
    }

    @Test func plainTextPayloadBecomesMessage() {
        let msg = InboxMessage.parse("aider waiting\nTests are red")
        #expect(AgentAdapters.event(from: msg)?.kind == .needsAttention(message: "Tests are red"))
    }

    @Test func hostAppComesFromMetadata() {
        let msg = InboxMessage.parse("claude done\n@host /Applications/Visual Studio Code.app\n{\"session_id\":\"s\"}")
        #expect(msg.meta["host"] == "/Applications/Visual Studio Code.app")
        #expect(AgentAdapters.event(from: msg)?.host == "/Applications/Visual Studio Code.app")
        #expect(msg.payload["session_id"] as? String == "s")
    }

    @Test func onlyAgentAppsCountAsWatching() {
        #expect(AgentApps.isDedicated(bundleID: "com.anthropic.claudefordesktop", appName: "Claude"))
        #expect(AgentApps.isDedicated(bundleID: nil, appName: "Codex"))
        #expect(!AgentApps.isDedicated(bundleID: "com.apple.Terminal", appName: "Terminal"))
        #expect(!AgentApps.isDedicated(bundleID: "com.microsoft.VSCode", appName: "Visual Studio Code"))
        #expect(!AgentApps.isDedicated(bundleID: "com.googlecode.iterm2", appName: "iTerm"))
    }

    @Test func frontmostWindowOwnerSkipsOverlaysAndTinyWindows() {
        let windows = [
            WindowInfo(ownerPID: 1, layer: 25, width: 400, height: 400),   // status-bar level overlay
            WindowInfo(ownerPID: 2, layer: 0, alpha: 0, width: 800, height: 600), // invisible
            WindowInfo(ownerPID: 3, layer: 0, width: 20, height: 20),       // tiny helper window
            WindowInfo(ownerPID: 4, layer: 0, width: 1200, height: 800),    // the real front window
            WindowInfo(ownerPID: 5, layer: 0, width: 1200, height: 800),
        ]
        #expect(ScreenWindows.frontmostOwner(windows) == 4)
        #expect(ScreenWindows.frontmostOwner([]) == nil)   // e.g. the only app is minimized
    }

    @Test func unknownEventsAreIgnored() {
        #expect(AgentAdapters.event(from: InboxMessage.parse("claude PreCompact\n{}")) == nil)
    }
}

@Suite struct AttentionQueueTests {
    func event(_ kind: AgentEvent.Kind, _ session: String = "claude:a") -> AgentEvent {
        AgentEvent(kind: kind, agent: "Claude", session: session, project: "p")
    }

    @Test func knockThenResumeGoesHome() {
        var q = AttentionQueue()
        #expect(q.apply(event(.finished)) == .knock)
        #expect(q.apply(event(.resumed)) == .empty)
        #expect(q.isEmpty)
    }

    @Test func resumeForUnknownSessionDoesNothing() {
        var q = AttentionQueue()
        #expect(q.apply(event(.resumed)) == .none)
    }

    @Test func multipleSessionsStayUntilAllResume() {
        var q = AttentionQueue()
        _ = q.apply(event(.finished, "claude:a"))
        _ = q.apply(event(.needsPermission, "codex:b"))
        #expect(q.entries.count == 2)
        #expect(q.apply(event(.resumed, "claude:a")) == .updated)
        #expect(q.apply(event(.resumed, "codex:b")) == .empty)
    }

    @Test func finishingWhileWatchingStaysQuiet() {
        var q = AttentionQueue()
        #expect(q.apply(event(.finished), watching: true) == .quietlyAdded)
        #expect(!q.needsKnock)
        #expect(q.apply(event(.resumed)) == .empty)
    }

    @Test func walkingAwayFromAQuietSessionKnocksOnTheReminder() {
        var q = AttentionQueue()
        _ = q.apply(event(.finished), watching: true)
        #expect(q.apply(event(.idleReminder), watching: true) == .none)
        #expect(q.apply(event(.idleReminder), watching: false) == .knock)
        #expect(q.needsKnock)
    }

    @Test func quietSessionsDontKeepTheBuddyKnocking() {
        var q = AttentionQueue()
        _ = q.apply(event(.finished, "claude:a"), watching: true)
        #expect(q.apply(event(.finished, "codex:b")) == .knock)
        #expect(q.apply(event(.resumed, "codex:b")) == .settle)
        #expect(q.entries.count == 1)
    }

    @Test func clickingClearsOnlyQuietOnes() {
        var q = AttentionQueue()
        _ = q.apply(event(.finished, "claude:a"), watching: true)
        _ = q.apply(event(.finished, "codex:b"))
        q.clearQuiet()
        #expect(q.entries.map(\.agent) == ["Claude"])
        #expect(q.needsKnock)
    }

    @Test func hintText() {
        let a = Waiting(agent: "Claude", project: "api", kind: .finished, quiet: true)
        let b = Waiting(agent: "Codex", project: "", kind: .finished, quiet: true)
        #expect(L10n(.en).hint(for: [a]) == "✓ api")
        #expect(L10n(.fa).hint(for: [a, b, b]) == "✓ api +۲")
        #expect(L10n(.en).hint(for: [b]) == "✓ Codex")
        #expect(L10n(.en).hint(for: []) == nil)
    }

    @Test func idleReminderDoesNotOverwritePermission() {
        var q = AttentionQueue()
        _ = q.apply(event(.needsPermission))
        #expect(q.apply(event(.idleReminder)) == .none)
        #expect(q.entries.first?.kind == .needsPermission)
    }
}

@Suite struct LocalizationTests {
    @Test func everyKeyHasBothLanguages() {
        for key in L10nKey.allCases {
            let pair = L10n.table[key]
            #expect(pair != nil, "missing \(key)")
            #expect(pair?.en.isEmpty == false && pair?.fa.isEmpty == false, "empty \(key)")
        }
    }

    @Test func systemLanguageFollowsPreferredLanguages() {
        #expect(L10n(.system, preferred: ["fa-IR", "en"]).language == .fa)
        #expect(L10n(.system, preferred: ["en-US", "fa-US"]).language == .en)
        #expect(L10n(.fa, preferred: ["en-US"]).isRTL)
    }

    @Test func bubbleTexts() {
        let one = [Waiting(agent: "Codex", project: "api", kind: .finished)]
        #expect(L10n(.en).bubble(for: one) == ("Codex is done! ✨", "waiting for you 👀 · api"))
        let two = one + [Waiting(agent: "Claude", project: "web", kind: .needsPermission)]
        #expect(L10n(.fa).bubble(for: two).title == "۲ تا ایجنت منتظرتن! 👀")
    }
}
