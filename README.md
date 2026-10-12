# ClaudeBuddy

A cute macOS desktop pet that lives on your wallpaper. It nods, blinks, wanders around, naps when you're
away, and — when an AI coding agent (Claude Code, Codex, or anything else) finishes or needs permission —
jumps up to the "glass" and knocks until you come back.

- **Characters:** Buddy (little guy), Robo, Ninja, and Kitty, Puppy & Bunny — real four-legged animals that walk on diagonal
  leg pairs, sit, stretch, curl up to sleep and rear up on their hind legs to paw at the glass. Pick one in Settings.
- **Mischief:** Calm (sits, looks around), Playful (walks, dances, jumps), Naughty (all that + chases your cursor).
- **Pet it:** click for hearts; drag it around (it dangles) and drop it — it falls back to the floor.
  Its eyes follow your cursor; it waves when you come close; it sleeps when you're idle.
- **Bilingual:** English / فارسی (or follow the system language).

## Download

1. Grab `ClaudeBuddy-<version>.zip` from [Releases](https://github.com/pooriaanv/claudBuddy-Mac/releases), unzip,
   move `ClaudeBuddy.app` to Applications.
2. It isn't notarized, so the first time: right-click → Open (or System Settings → Privacy & Security → Open Anyway).
3. Menu-bar face → Settings… → Agents → Connect Claude Code and/or Codex.

**Updates:** the app checks GitHub Releases on launch and about once a day (or menu → Check for Updates…).
A newer version is downloaded, verified (GitHub's SHA-256, code signature, bundle id, version) and swapped in,
then the app relaunches — automatically unless you turn that off in Settings; never while it's knocking.

## Build & install

```bash
./build.sh
```

- App: `~/Applications/ClaudeBuddy.app` (menu-bar icon, no Dock icon). Restarts itself if it was running.
- Hook script: `~/.claude-buddy/notify.sh`
- Settings: menu-bar icon → Settings…  (character, mischief, size, sound, language, agents, open at login)

```bash
swift test                     # core logic tests
scripts/package.sh             # build + zip for a release → dist/ClaudeBuddy-<version>.zip
```

## Releasing

1. Bump `VERSION`, add a `## <version>` section to `CHANGELOG.md`, commit.
2. `git tag -a v<version> -m "ClaudeBuddy <version>" && git push origin v<version>`

The [Release workflow](.github/workflows/release.yml) then tests, builds, zips and publishes the GitHub release
(notes from `CHANGELOG.md` + install steps + SHA-256). It refuses tags that don't match `VERSION`.

## Connecting agents

Settings → Agents → Connect, or from the command line:

```bash
~/Applications/ClaudeBuddy.app/Contents/MacOS/ClaudeBuddy --connect claude   # ~/.claude/settings.json
~/Applications/ClaudeBuddy.app/Contents/MacOS/ClaudeBuddy --connect codex    # ~/.codex/hooks.json
```

Both tools get the same hooks (a `.buddy-backup` of the original file is kept):

| Hook | Runs | Effect |
|---|---|---|
| `Stop` | `notify.sh <agent> done` | come knock |
| `Notification` (Claude) / `PermissionRequest` (Codex) | `… waiting` / `… permission` | knock: needs your OK |
| `UserPromptSubmit`, `PostToolUse` | `… dismiss` | you're back → go home |

**Already looking?** (optional, off by default — Settings → Behavior) `notify.sh` records which app the session runs in (the topmost `.app` in its process
tree). If that's the agent's own app (Claude / Codex desktop), it's frontmost, and you've been active in the
last 15 s, the buddy doesn't knock — it shows a small `✓ project` hint above its head and a red dot on the
menu-bar face. Sessions in Terminal, iTerm, VS Code, Cursor… always get a knock (you're in those apps for
other work too). If you walk away, the agent's "still waiting" reminder makes it knock after all.

Codex: after connecting, run `/hooks` in Codex once and trust the buddy hooks.
Codex's legacy `notify = ["~/.claude-buddy/notify.sh", "codex"]` also works.

**Any other tool** can call it:

```bash
~/.claude-buddy/notify.sh gemini done '{"project": "blog"}'
~/.claude-buddy/notify.sh aider waiting '{"message": "tests are red"}'
~/.claude-buddy/notify.sh gemini dismiss
```

## Architecture

```
Sources/
  BuddyCore/                 pure logic, no AppKit — unit tested
    Agents.swift             AgentEvent + adapters (Claude/Codex hooks, generic tools)
    Inbox.swift              event files written by notify.sh
    Attention.swift          who's waiting → knock / update / go home
    Brain.swift              idle behavior state machine (sit, walk, dance, sleep, wave, chase…)
    Animation.swift          Animator: state + time → PetScene (pose + effects); knock choreography
    Pose.swift               Pose, PetScene, SkinID
    Localization.swift       en / fa strings
  ClaudeBuddy/               the macOS app
    Coordinator.swift        wires inbox → queue → pet; preferences → everything
    PetController.swift      window on the desktop floor: walking, drag/drop, falling, knocking, frame clock
    PetWindow.swift          transparent panel + mouse handling
    Render/SceneRenderer     draws a PetScene: shadow, transforms, effects, speech bubble
    Render/Skins/*.swift     one file per character; Quadruped.swift is the shared four-legged rig
    KnockSound.swift         synthesized knock per character (knuckle / paw / metal)
    Integrations.swift       install/remove agent hooks; open-at-login LaunchAgent
    Settings/                SwiftUI settings window with live previews
    StatusMenu.swift         menu-bar menu
scripts/notify.sh            the hook script (installed to ~/.claude-buddy/)
```

Flow: agent hook → `notify.sh` drops `~/.claude-buddy/inbox/*.evt` → `Coordinator` polls →
`AgentAdapters` → `AttentionQueue` → `PetController.knock()` / `goHome()`.
Every frame: `Brain` decides the activity → `Animator` builds a `PetScene` → a `Skin` draws it.

### Extending

- **New character:** add a case to `SkinID` (+ name in `L10n`), write `Render/Skins/XSkin.swift`
  implementing `Skin` (draw a `Pose` in the 200×300 character space) — or `QuadrupedSkin` for a four-legged
  animal (just colors, tail shapes, markings and a head) — and register it in `SkinCatalog`.
- **New behavior:** add an `Activity` case, give it weight/duration in `Brain`, a pose in `Animator.apply`.
- **New agent:** usually nothing — use `notify.sh <name> <event>`. For a custom payload format, write an
  `AgentAdapter` and add it to `AgentAdapters.known`. For one-click setup, add a case to `AgentIntegration`.
- **New strings:** add an `L10nKey` with both languages (a test fails if one is missing).

## Debugging

```bash
.build/release/ClaudeBuddy --snapshot sheet.png fa   # every character × every pose, as a PNG
BUDDY_DEBUG=1 .build/release/ClaudeBuddy             # logs frame-rate / activity changes
```

The frame rate follows what's on screen: 8 fps asleep, 12 sitting, 30 moving, 60 while knocking or carried.
