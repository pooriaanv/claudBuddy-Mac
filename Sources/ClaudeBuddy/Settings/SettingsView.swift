import AppKit
import BuddyCore
import SwiftUI

struct SettingsView: View {
    @ObservedObject var prefs: Preferences
    @ObservedObject var updater: Updater
    let onTestKnock: () -> Void
    let onCheckUpdates: () -> Void
    let onInstallUpdate: () -> Void
    @State private var agentRefresh = 0
    @State private var launchAtLogin = LaunchAtLogin.isEnabled
    @State private var error: String?

    private var l: L10n { prefs.l10n }

    var body: some View {
        Form {
            Section(l(.sectionCharacter)) {
                HStack(spacing: 10) {
                    ForEach(SkinID.allCases) { skin in skinCard(skin) }
                }
                .padding(.vertical, 4)
            }

            Section(l(.sectionBehavior)) {
                Picker(l(.mischief), selection: $prefs.mischief) {
                    Text(l(.mischiefCalm)).tag(Mischief.calm)
                    Text(l(.mischiefPlayful)).tag(Mischief.playful)
                    Text(l(.mischiefNaughty)).tag(Mischief.naughty)
                }
                .pickerStyle(.segmented)
                Text(l(.mischiefHint)).font(.caption).foregroundStyle(.secondary)
                Slider(value: $prefs.size, in: 110...230) { Text(l(.size)) }
                HStack {
                    Toggle(l(.sound), isOn: $prefs.soundOn)
                    Spacer()
                    Button(l(.testKnock), action: onTestKnock)
                }
                Toggle(l(.quietWhenWatching), isOn: $prefs.quietWhenWatching)
                Text(l(.quietHint)).font(.caption).foregroundStyle(.secondary)
                Toggle(l(.launchAtLogin), isOn: Binding(
                    get: { launchAtLogin },
                    set: { on in
                        do { try LaunchAtLogin.set(on); launchAtLogin = on } catch { self.error = error.localizedDescription }
                    }))
            }

            Section(l(.sectionLanguage)) {
                Picker(l(.sectionLanguage), selection: $prefs.language) {
                    Text(l(.languageSystem)).tag(Language.system)
                    Text("English").tag(Language.en)
                    Text("فارسی").tag(Language.fa)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }

            Section(l(.sectionUpdates)) {
                HStack {
                    Text(updateStatus).foregroundStyle(updateStatusIsError ? Color.red : Color.primary)
                    Spacer()
                    if updater.available != nil && updater.canInstall {
                        Button(l(.installNow), action: onInstallUpdate).buttonStyle(.borderedProminent)
                    } else {
                        Button(l(.checkNow), action: onCheckUpdates)
                            .disabled(updater.state == .checking || updater.state == .installing)
                    }
                }
                Toggle(l(.updatesAuto), isOn: $prefs.autoUpdate)
            }

            Section(l(.sectionAgents)) {
                ForEach(AgentIntegration.allCases) { agent in agentRow(agent) }
                Text(l(.codexTrustHint)).font(.caption).foregroundStyle(.secondary)
                Text(l(.otherAgentsHint)).font(.caption.monospaced()).foregroundStyle(.secondary).textSelection(.enabled)
            }
        }
        .formStyle(.grouped)
        .frame(width: 540)
        .fixedSize(horizontal: false, vertical: true)
        .environment(\.layoutDirection, l.isRTL ? .rightToLeft : .leftToRight)
        .alert(error ?? "", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
            Button("OK", role: .cancel) {}
        }
    }

    private var updateStatus: String {
        let current = updater.current.description
        switch updater.state {
        case .idle: return l.format(.updateVersion, v: current)
        case .checking: return l(.updateChecking)
        case .upToDate: return l.format(.updateUpToDate, v: current)
        case .available(let r): return l.format(.updateAvailable, v: r.version.description)
        case .installing: return l(.updateInstalling)
        case .failed(let message): return l.format(.updateFailed, v: message)
        }
    }

    private var updateStatusIsError: Bool {
        if case .failed = updater.state { return true }
        return false
    }

    private func skinCard(_ skin: SkinID) -> some View {
        let selected = prefs.skin == skin
        return Button {
            prefs.skin = skin
        } label: {
            VStack(spacing: 4) {
                SkinPreview(skin: skin, activity: selected ? .wave : .sit)
                    .frame(width: 96, height: 128)
                Text(l(skin.nameKey)).font(.callout.weight(selected ? .semibold : .regular))
            }
            .padding(6)
            .background(RoundedRectangle(cornerRadius: 12).fill(selected ? Color.accentColor.opacity(0.15) : Color.clear))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(selected ? Color.accentColor : Color.secondary.opacity(0.25), lineWidth: selected ? 2 : 1))
        }
        .buttonStyle(.plain)
    }

    private func agentRow(_ agent: AgentIntegration) -> some View {
        let _ = agentRefresh
        let connected = agent.isConnected
        return HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(agent.displayName).font(.body.weight(.medium))
                Group {
                    if connected {
                        Label(l(.connected), systemImage: "checkmark.circle.fill").foregroundStyle(.green)
                    } else if !agent.toolDetected {
                        Text("\(l(.notConnected)) · \(l(.toolNotFound))").foregroundStyle(.secondary)
                    } else {
                        Text(l(.notConnected)).foregroundStyle(.secondary)
                    }
                }
                .font(.caption)
            }
            Spacer()
            Button(connected ? l(.disconnect) : l(.connect)) {
                do {
                    if connected { try agent.disconnect() } else { try agent.connect() }
                } catch {
                    self.error = error.localizedDescription
                }
                agentRefresh += 1
            }
        }
    }
}

final class SettingsWindowController: NSObject, NSWindowDelegate {
    private unowned let coordinator: Coordinator
    private var window: NSWindow?

    init(coordinator: Coordinator) {
        self.coordinator = coordinator
    }

    func show() {
        if window == nil {
            let view = SettingsView(prefs: coordinator.prefs, updater: coordinator.updater,
                                    onTestKnock: { [weak coordinator] in coordinator?.testKnock() },
                                    onCheckUpdates: { [weak coordinator] in coordinator?.checkForUpdates() },
                                    onInstallUpdate: { [weak coordinator] in coordinator?.installUpdate() })
            let w = NSWindow(contentViewController: NSHostingController(rootView: view))
            w.styleMask = [.titled, .closable]
            w.isReleasedWhenClosed = false
            w.delegate = self
            w.center()
            window = w
        }
        updateTitle()
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    func updateTitle() {
        window?.title = coordinator.prefs.l10n(.settingsTitle)
    }

    func windowWillClose(_ notification: Notification) {
        // Drop the window so its live previews stop animating.
        window = nil
    }
}
