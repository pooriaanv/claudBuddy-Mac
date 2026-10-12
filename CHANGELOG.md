# Changelog

Each `## <version>` section becomes the GitHub release notes for tag `v<version>`.

## 0.0.8

- New **Ninja** look, "Shadow": all-black mask with glowing slit eyes, crossed arms while idle, tattered crimson
  scarf, scratched-out headband plate, shoulder armor, smoke at its feet, and a glowing katana when it dances
- **Cyber Ninja**: the same ninja with cyan eyes and blade (pick either in Settings)

## 0.0.7

- Two new characters: **Bunny** (four legs, hops instead of walking, floppy ears when sleepy) and **Ninja**
  (red headband with fluttering tails, katana on its back — it draws the sword when it dances)
- The knocking buddy is 20% smaller on screen

## 0.0.6

- Fix: with "Don't knock if I'm already in the Claude / Codex app" on, a **minimized** Claude window still counted
  as "looking" (a minimized app stays the active app), so the buddy only showed the hint. Now the agent's window
  has to actually be the top window on screen.

## 0.0.5

- "Don't knock if I'm already in the Claude / Codex app" is now **off by default**, so the buddy always knocks
  out of the box. The app can't tell which session is on screen, so quiet mode could hide knocks for other
  sessions. Turn it on in Settings → Behavior if you want it.

## 0.0.4

- Knocks reliably for Claude Code in Terminal, iTerm, VS Code, Cursor…: the "already looking" quiet mode now only
  applies to the agent's own app (Claude / Codex desktop)
- "Already looking" means active in the last 15 s (was 45 s)

## 0.0.3

- Settings fit smaller screens: four tabs (Character, Behavior, Agents, Updates), a resizable window that never
  gets taller than the screen, and tabs that scroll when needed

## 0.0.2

- Update checker: checks GitHub Releases on launch and daily, downloads, verifies and installs new versions,
  then relaunches (Settings → Updates; menu → Check for Updates…)

## 0.0.1

First release of ClaudeBuddy — a cute desktop pet for macOS that lives on your wallpaper and knocks on the
"glass" when your AI coding agent is done.

- Four characters: Buddy, Robo, and four-legged Kitty & Puppy
- Lives on the desktop: walks, sits, dances, naps when you're away, follows your cursor, waves; drag it around
  and it falls back to the floor; click it for hearts
- When Claude Code, Codex (or any tool via `notify.sh`) finishes or needs permission, it comes up to the screen
  and knocks, with a speech bubble saying who's waiting
- Already looking at the agent's window? It stays quiet: a red dot on the menu-bar face and a small
  `✓ project` tag above its head
- English / فارسی, three mischief levels, size, sound, open at login
