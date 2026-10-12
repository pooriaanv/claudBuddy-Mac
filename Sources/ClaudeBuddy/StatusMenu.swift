import AppKit
import BuddyCore

/// The little figure in the menu bar.
final class StatusMenu: NSObject {
    private unowned let coordinator: Coordinator
    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private var waiting: [Waiting] = []

    init(coordinator: Coordinator) {
        self.coordinator = coordinator
        super.init()
        rebuild()
    }

    /// Shows who's waiting (including quiet ones) and puts a dot on the icon.
    func update(waiting: [Waiting]) {
        self.waiting = waiting
        rebuild()
    }

    func rebuild() {
        let l = coordinator.prefs.l10n
        item.button?.image = AppIcon.menuBarImage(coordinator.prefs.skin, badge: !waiting.isEmpty)
        item.button?.toolTip = "Claude Buddy"
        let menu = NSMenu()
        menu.userInterfaceLayoutDirection = l.isRTL ? .rightToLeft : .leftToRight
        if !waiting.isEmpty {
            let header = NSMenuItem(title: l(.menuWaiting), action: nil, keyEquivalent: "")
            header.isEnabled = false
            menu.addItem(header)
            for w in waiting {
                let b = l.bubble(for: [w])
                let i = NSMenuItem(title: "\(b.title)  \(w.project)", action: nil, keyEquivalent: "")
                i.isEnabled = false
                menu.addItem(i)
            }
            menu.addItem(.separator())
        }
        if let update = coordinator.updater.available {
            menu.addItem(entry(l.format(.menuInstallUpdate, v: update.version.description), #selector(installUpdate)))
            menu.addItem(.separator())
        }
        menu.addItem(entry(l(.menuSettings), #selector(openSettings), key: ","))
        menu.addItem(entry(l(.menuCheckUpdates), #selector(checkUpdates)))
        menu.addItem(.separator())
        menu.addItem(entry(l(.menuTestKnock), #selector(testKnock)))
        menu.addItem(entry(l(.menuSendHome), #selector(sendHome)))
        let mute = entry(l(.menuMute), #selector(toggleMute))
        mute.state = coordinator.prefs.soundOn ? .off : .on
        menu.addItem(mute)
        menu.addItem(.separator())
        menu.addItem(entry(l(.menuQuit), #selector(quit), key: "q"))
        item.menu = menu
    }

    private func entry(_ title: String, _ action: Selector, key: String = "") -> NSMenuItem {
        let i = NSMenuItem(title: title, action: action, keyEquivalent: key)
        i.target = self
        return i
    }

    @objc private func openSettings() { coordinator.openSettings() }
    @objc private func checkUpdates() { coordinator.checkForUpdates() }
    @objc private func installUpdate() { coordinator.installUpdate() }
    @objc private func testKnock() { coordinator.testKnock() }
    @objc private func sendHome() { coordinator.dismissAll() }
    @objc private func toggleMute() { coordinator.prefs.soundOn.toggle() }
    @objc private func quit() {
        BuddyPaths.setActive(false)
        NSApp.terminate(nil)
    }
}
