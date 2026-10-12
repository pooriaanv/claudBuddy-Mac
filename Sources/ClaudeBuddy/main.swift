import AppKit
import BuddyCore

// Debug / setup commands:
//   ClaudeBuddy --snapshot out.png [en|fa]     render every skin in every pose
//   ClaudeBuddy --iconset out.iconset          render the app icon (build.sh turns it into .icns)
//   ClaudeBuddy --connect claude|codex         install the agent's hooks
//   ClaudeBuddy --disconnect claude|codex      remove them
let args = CommandLine.arguments
if args.count >= 3 {
    switch args[1] {
    case "--snapshot":
        Snapshot.render(to: args[2], language: args.count > 3 ? (Language(rawValue: args[3]) ?? .en) : .en)
        exit(0)
    case "--iconset":
        do {
            try AppIcon.writeIconset(to: URL(fileURLWithPath: args[2]))
            exit(0)
        } catch {
            print("failed: \(error.localizedDescription)")
            exit(1)
        }
    case "--connect", "--disconnect":
        guard let agent = AgentIntegration(rawValue: args[2]) else {
            print("unknown agent \(args[2]); use: \(AgentIntegration.allCases.map(\.rawValue).joined(separator: ", "))")
            exit(1)
        }
        do {
            if args[1] == "--connect" { try agent.connect() } else { try agent.disconnect() }
            print("\(agent.displayName): \(agent.isConnected ? "connected" : "not connected") (\(agent.configURL.path))")
            exit(0)
        } catch {
            print("failed: \(error.localizedDescription)")
            exit(1)
        }
    default:
        break
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    let coordinator = Coordinator()
    func applicationDidFinishLaunching(_ notification: Notification) { coordinator.start() }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
