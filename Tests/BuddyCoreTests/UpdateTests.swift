import Foundation
import Testing
@testable import BuddyCore

@Suite struct UpdateTests {
    func v(_ s: String) -> SemanticVersion { SemanticVersion(s)! }

    @Test func versionsCompareNumerically() {
        #expect(v("0.0.2") > v("0.0.1"))
        #expect(v("0.10.0") > v("0.9.9"))
        #expect(v("v1.2") == v("1.2.0"))
        #expect(v("1.0.0-beta") == v("1.0.0"))
        #expect(SemanticVersion("latest") == nil)
        #expect(SemanticVersion("") == nil)
    }

    @Test func parsesLatestRelease() throws {
        let json = """
        {"tag_name": "v0.0.2", "draft": false, "prerelease": false,
         "html_url": "https://github.com/o/r/releases/tag/v0.0.2",
         "assets": [
           {"name": "notes.txt", "browser_download_url": "https://example.com/notes.txt"},
           {"name": "ClaudeBuddy-0.0.2.zip", "digest": "sha256:ABC123",
            "browser_download_url": "https://github.com/o/r/releases/download/v0.0.2/ClaudeBuddy-0.0.2.zip"}
         ]}
        """
        let r = try #require(ReleaseInfo.parse(Data(json.utf8)))
        #expect(r.version == v("0.0.2"))
        #expect(r.zipURL.lastPathComponent == "ClaudeBuddy-0.0.2.zip")
        #expect(r.sha256 == "abc123")
    }

    @Test func rejectsReleasesWithoutAUsableZip() {
        let noZip = #"{"tag_name": "v1.0.0", "assets": [{"name": "x.dmg", "browser_download_url": "https://e.com/x.dmg"}]}"#
        let insecure = #"{"tag_name": "v1.0.0", "assets": [{"name": "ClaudeBuddy-1.0.0.zip", "browser_download_url": "http://e.com/a.zip"}]}"#
        let prerelease = #"{"tag_name": "v1.0.0", "prerelease": true, "assets": [{"name": "ClaudeBuddy-1.0.0.zip", "browser_download_url": "https://e.com/a.zip"}]}"#
        #expect(ReleaseInfo.parse(Data(noZip.utf8)) == nil)
        #expect(ReleaseInfo.parse(Data(insecure.utf8)) == nil)
        #expect(ReleaseInfo.parse(Data(prerelease.utf8)) == nil)
    }
}
