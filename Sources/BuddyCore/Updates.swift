import Foundation

/// "0.0.2", "v1.2" … compared numerically, missing parts count as 0. Pre-release suffixes ("-beta") are ignored.
public struct SemanticVersion: Comparable, CustomStringConvertible {
    public let parts: [Int]

    public init?(_ string: String) {
        var s = string.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("v") || s.hasPrefix("V") { s.removeFirst() }
        s = String(s.prefix { $0 != "-" && $0 != "+" })
        let parts = s.split(separator: ".").map { Int($0) }
        guard !parts.isEmpty, !parts.contains(where: { $0 == nil }) else { return nil }
        self.parts = parts.compactMap { $0 }
    }

    public var description: String { parts.map(String.init).joined(separator: ".") }

    public static func < (a: SemanticVersion, b: SemanticVersion) -> Bool {
        for i in 0..<max(a.parts.count, b.parts.count) {
            let x = i < a.parts.count ? a.parts[i] : 0
            let y = i < b.parts.count ? b.parts[i] : 0
            if x != y { return x < y }
        }
        return false
    }

    public static func == (a: SemanticVersion, b: SemanticVersion) -> Bool { !(a < b) && !(b < a) }
}

/// The parts of a GitHub "latest release" response the updater needs.
public struct ReleaseInfo: Equatable {
    public var tag: String
    public var version: SemanticVersion
    public var zipURL: URL
    /// Hex SHA-256 of the zip, from GitHub's asset digest, when available.
    public var sha256: String?
    public var pageURL: URL?

    /// Parses `GET /repos/{owner}/{repo}/releases/latest`. Picks the `<assetPrefix>*.zip` asset.
    public static func parse(_ data: Data, assetPrefix: String = "ClaudeBuddy-") -> ReleaseInfo? {
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tag = obj["tag_name"] as? String,
              let version = SemanticVersion(tag),
              (obj["draft"] as? Bool) != true, (obj["prerelease"] as? Bool) != true,
              let assets = obj["assets"] as? [[String: Any]],
              let zip = assets.first(where: {
                  let name = $0["name"] as? String ?? ""
                  return name.hasPrefix(assetPrefix) && name.hasSuffix(".zip")
              }),
              let urlString = zip["browser_download_url"] as? String,
              let url = URL(string: urlString), url.scheme == "https"
        else { return nil }

        var sha: String?
        if let digest = zip["digest"] as? String, digest.hasPrefix("sha256:") {
            sha = String(digest.dropFirst("sha256:".count)).lowercased()
        }
        return ReleaseInfo(tag: tag, version: version, zipURL: url, sha256: sha,
                           pageURL: (obj["html_url"] as? String).flatMap(URL.init(string:)))
    }
}
