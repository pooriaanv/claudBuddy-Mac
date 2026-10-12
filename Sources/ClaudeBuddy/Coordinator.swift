import AppKit
import BuddyCore
import Combine

/// Wires everything together: agent events → attention queue → pet; preferences → pet, menu, settings.
final class Coordinator: NSObject {
    let prefs = Preferences()
    let updater = Updater()
    private(set) lazy var pet = PetController(prefs: prefs)
    private var queue = AttentionQueue()
    private let inbox = InboxDirectory(url: BuddyPaths.inbox)
    private var menu: StatusMenu!
    private var settings: SettingsWindowController?
    private var observers = Set<AnyCancellable>()

    func start() {
        try? FileManager.default.createDirectory(at: BuddyPaths.inbox, withIntermediateDirectories: true)
        BuddyPaths.installNotifyScript()
        BuddyPaths.setActive(false)
        inbox.clean(olderThan: 15)

        pet.onDismissRequested = { [weak self] in self?.dismissAll() }
        pet.onPetted = { [weak self] in
            guard let self, self.queue.entries.contains(where: \.quiet) else { return }
            self.queue.clearQuiet()
            self.queueChanged()
        }
        pet.start()
        menu = StatusMenu(coordinator: self)

        prefs.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.preferencesChanged() }
            .store(in: &observers)

        Timer.scheduledTimer(withTimeInterval: 0.4, repeats: true) { [weak self] _ in self?.pollInbox() }
        pollInbox()

        updater.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.updaterChanged() }
            .store(in: &observers)
        Timer.scheduledTimer(withTimeInterval: 10, repeats: false) { [weak self] _ in self?.checkForUpdatesIfDue() }
        Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { [weak self] _ in self?.checkForUpdatesIfDue() }
    }

    // MARK: updates

    /// At most about once a day on its own.
    private func checkForUpdatesIfDue() {
        let last = UserDefaults.standard.object(forKey: "lastUpdateCheck") as? Date ?? .distantPast
        if Date().timeIntervalSince(last) > 20 * 3600 { checkForUpdates() }
    }

    func checkForUpdates() {
        Task { @MainActor in await updater.check() }
    }

    func installUpdate() {
        guard let release = updater.available else { return }
        Task { @MainActor in await updater.install(release) }
    }

    private func updaterChanged() {
        menu.rebuild()
        installUpdateIfAllowed()
    }

    /// Auto-install only when nothing is waiting and the buddy is just hanging out.
    private func installUpdateIfAllowed() {
        guard prefs.autoUpdate, updater.canInstall, updater.available != nil, queue.isEmpty, pet.mode == .idle else { return }
        installUpdate()
    }

    // MARK: agent events

    private func pollInbox() {
        for message in inbox.drain() {
            guard let event = AgentAdapters.event(from: message) else { continue }
            handle(event)
        }
    }

    func handle(_ event: AgentEvent) {
        let watching = prefs.quietWhenWatching && Focus.isWatching(host: event.host)
        switch queue.apply(event, watching: watching) {
        case .knock:
            let b = prefs.l10n.bubble(for: queue.entries)
            pet.knock(title: b.title, subtitle: b.subtitle)
        case .updated:
            refreshBubble()
        case .settle, .empty:
            pet.goHome()
        case .quietlyAdded, .none:
            break
        }
        queueChanged()
    }

    func dismissAll() {
        queue.clear()
        pet.goHome()
        queueChanged()
    }

    /// notify.sh only forwards "dismiss" events while something is waiting; the menu shows who.
    private func queueChanged() {
        BuddyPaths.setActive(!queue.isEmpty)
        menu.update(waiting: queue.entries)
        pet.hint = prefs.l10n.hint(for: queue.entries.filter(\.quiet))
        installUpdateIfAllowed()
    }

    func testKnock() {
        handle(AgentEvent(kind: .finished, agent: "Claude", session: "test:\(UUID().uuidString)", project: "ClaudeBuddy"))
    }

    private func refreshBubble() {
        let b = prefs.l10n.bubble(for: queue.entries)
        pet.updateBubble(title: b.title, subtitle: b.subtitle)
    }

    // MARK: settings

    func openSettings() {
        if settings == nil { settings = SettingsWindowController(coordinator: self) }
        settings?.show()
    }

    private func preferencesChanged() {
        pet.relayout()
        menu.rebuild()
        settings?.updateTitle()
        if !queue.isEmpty { refreshBubble() }
    }
}
