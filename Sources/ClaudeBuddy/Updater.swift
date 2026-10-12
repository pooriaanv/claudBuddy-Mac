import AppKit
import BuddyCore
import CryptoKit

/// Checks GitHub Releases for a newer version, downloads the zip, verifies it, swaps the app bundle and relaunches.
final class Updater: ObservableObject {
    static let repo = "pooriaanv/claudBuddy-Mac"

    enum State: Equatable {
        case idle, checking, upToDate, available(ReleaseInfo), installing
        case failed(String)
    }

    @Published private(set) var state: State = .idle

    /// Installed app version. `BUDDY_FAKE_VERSION=0.0.0` pretends to be older (for testing updates).
    let current: SemanticVersion = {
        if let fake = ProcessInfo.processInfo.environment["BUDDY_FAKE_VERSION"], let v = SemanticVersion(fake) { return v }
        let s = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
        return SemanticVersion(s) ?? SemanticVersion("0")!
    }()

    /// Only a real .app bundle can replace itself (not `swift run` / debug builds).
    var canInstall: Bool { Bundle.main.bundleURL.pathExtension == "app" }

    var available: ReleaseInfo? {
        if case .available(let r) = state { return r }
        return nil
    }

    @MainActor
    func check() async {
        guard state != .checking, state != .installing else { return }
        state = .checking
        do {
            var request = URLRequest(url: URL(string: "https://api.github.com/repos/\(Self.repo)/releases/latest")!)
            request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
            request.timeoutInterval = 20
            let (data, response) = try await URLSession.shared.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200, let release = ReleaseInfo.parse(data) else {
                throw UpdateError("no release found")
            }
            UserDefaults.standard.set(Date(), forKey: "lastUpdateCheck")
            state = release.version > current ? .available(release) : .upToDate
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    /// Downloads, verifies and installs `release`, then relaunches. Returns only on failure.
    @MainActor
    func install(_ release: ReleaseInfo) async {
        guard canInstall else {
            state = .failed("not running from an .app bundle")
            return
        }
        state = .installing
        do {
            let work = FileManager.default.temporaryDirectory.appendingPathComponent("ClaudeBuddy-update-\(UUID().uuidString)")
            try FileManager.default.createDirectory(at: work, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(at: work) }

            let (downloaded, response) = try await URLSession.shared.download(from: release.zipURL)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw UpdateError("download failed") }
            let zip = work.appendingPathComponent("update.zip")
            try FileManager.default.moveItem(at: downloaded, to: zip)

            if let expected = release.sha256 {
                let actual = SHA256.hash(data: try Data(contentsOf: zip)).map { String(format: "%02x", $0) }.joined()
                guard actual == expected else { throw UpdateError("checksum mismatch") }
            }

            try run("/usr/bin/ditto", ["-x", "-k", zip.path, work.path])
            let newApp = work.appendingPathComponent("ClaudeBuddy.app")
            guard let bundle = Bundle(url: newApp),
                  bundle.bundleIdentifier == Bundle.main.bundleIdentifier,
                  let version = (bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String).flatMap(SemanticVersion.init),
                  version == release.version
            else { throw UpdateError("unexpected app in the download") }
            try run("/usr/bin/codesign", ["--verify", "--deep", newApp.path])
            try? run("/usr/bin/xattr", ["-dr", "com.apple.quarantine", newApp.path])

            let target = Bundle.main.bundleURL
            _ = try FileManager.default.replaceItemAt(target, withItemAt: newApp)
            relaunch(target)
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    /// Waits for this process to quit, then opens the (new) app.
    @MainActor
    private func relaunch(_ app: URL) {
        let script = "while kill -0 \(ProcessInfo.processInfo.processIdentifier) 2>/dev/null; do sleep 0.2; done; open \"$0\""
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/bin/sh")
        p.arguments = ["-c", script, app.path]
        try? p.run()
        BuddyPaths.setActive(false)
        NSApp.terminate(nil)
    }

    private func run(_ tool: String, _ args: [String]) throws {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: tool)
        p.arguments = args
        p.standardOutput = FileHandle.nullDevice
        p.standardError = FileHandle.nullDevice
        try p.run()
        p.waitUntilExit()
        guard p.terminationStatus == 0 else { throw UpdateError("\((tool as NSString).lastPathComponent) failed") }
    }
}

struct UpdateError: LocalizedError {
    let message: String
    init(_ message: String) { self.message = message }
    var errorDescription: String? { message }
}
