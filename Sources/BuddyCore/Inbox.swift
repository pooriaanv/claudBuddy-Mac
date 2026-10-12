import Foundation

/// One event file dropped by `notify.sh`.
///
/// File format: first line `"<source> <event>"`, then optional `@key value` lines (e.g. `@host /Applications/Claude.app`),
/// then the hook's JSON payload. The original single-word first line (`done` / `waiting` / `dismiss`) means source `claude`.
public struct InboxMessage {
    public var source: String
    public var event: String
    public var payload: [String: Any]
    public var meta: [String: String]

    public init(source: String, event: String, payload: [String: Any], meta: [String: String] = [:]) {
        self.source = source
        self.event = event
        self.payload = payload
        self.meta = meta
    }

    public static func parse(_ text: String) -> InboxMessage {
        let header = String(text.prefix { $0 != "\n" })
        var rest = Substring(text.drop { $0 != "\n" }.dropFirst())
        var meta: [String: String] = [:]
        while rest.hasPrefix("@") {
            let line = rest.prefix { $0 != "\n" }
            rest = rest.dropFirst(line.count).dropFirst()
            let parts = line.dropFirst().split(separator: " ", maxSplits: 1)
            if parts.count == 2 { meta[String(parts[0])] = String(parts[1]) }
        }
        let body = rest.trimmingCharacters(in: .whitespacesAndNewlines)
        let words = header.split(separator: " ").map(String.init)
        let source = words.count >= 2 ? words[0] : "claude"
        let event = words.count >= 2 ? words[1] : (words.first ?? "")

        var payload: [String: Any] = [:]
        if !body.isEmpty {
            if let obj = try? JSONSerialization.jsonObject(with: Data(body.utf8)) as? [String: Any] {
                payload = obj
            } else {
                payload = ["message": body]
            }
        }
        return InboxMessage(source: source, event: event, payload: payload, meta: meta)
    }
}

/// The folder `notify.sh` drops event files into.
public struct InboxDirectory {
    public let url: URL

    public init(url: URL) { self.url = url }

    /// Reads and deletes all pending events, oldest first.
    public func drain() -> [InboxMessage] {
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(at: url, includingPropertiesForKeys: nil) else { return [] }
        return files
            .filter { $0.pathExtension == "evt" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
            .map { file in
                let text = (try? String(contentsOf: file, encoding: .utf8)) ?? ""
                try? fm.removeItem(at: file)
                return InboxMessage.parse(text)
            }
    }

    /// Drops stale events (e.g. ones written while the app wasn't running).
    public func clean(olderThan seconds: TimeInterval) {
        let fm = FileManager.default
        let keys: [URLResourceKey] = [.contentModificationDateKey]
        guard let files = try? fm.contentsOfDirectory(at: url, includingPropertiesForKeys: keys) else { return }
        for file in files {
            let date = (try? file.resourceValues(forKeys: Set(keys)))?.contentModificationDate ?? .distantPast
            if Date().timeIntervalSince(date) > seconds { try? fm.removeItem(at: file) }
        }
    }
}
