# peon-ping

![macOS](https://img.shields.io/badge/macOS-only-blue)
![License](https://img.shields.io/badge/license-MIT-green)
![Claude Code](https://img.shields.io/badge/Claude_Code-hook-ffab01)

**Your Peon pings you when Claude Code needs attention.**

Claude Code doesn't notify you when it finishes or needs permission. You tab away, lose focus, and waste 15 minutes getting back into flow. peon-ping fixes this with Warcraft III Peon voice lines — so you never miss a beat, and your terminal sounds like Orgrimmar.

**See it in action** &rarr; [peon-ping.vercel.app](https://peon-ping.vercel.app/)

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/tonyyont/peon-ping/main/install.sh | bash
```

One command. Takes 10 seconds. macOS only. Re-run to update (sounds and config preserved).

## What you'll hear

| Event | Sound | Examples |
|---|---|---|
| Session starts | Greeting | *"Ready to work?"*, *"Yes?"*, *"What you want?"* |
| Task finishes | Acknowledgment | *"Work, work."*, *"I can do that."*, *"Okie dokie."* |
| Permission needed | Alert | *"Something need doing?"*, *"Hmm?"*, *"What you want?"* |
| Rapid prompts (3+ in 10s) | Easter egg | *"Me busy, leave me alone!"* |

Plus Terminal tab titles (`● project: done`) and macOS notifications when Terminal isn't focused.

## Configuration

Edit `~/.claude/hooks/peon-ping/config.json`:

```json
{
  "volume": 0.5,
  "categories": {
    "greeting": true,
    "acknowledge": true,
    "complete": true,
    "error": true,
    "permission": true,
    "annoyed": true
  }
}
```

- **volume**: 0.0–1.0 (quiet enough for the office)
- **categories**: Toggle individual sound types on/off
- **annoyed_threshold / annoyed_window_seconds**: How many prompts in N seconds triggers the easter egg

## Character packs

Swappable sound packs. To add one:

1. Create `packs/<name>/manifest.json` (see `packs/peon/manifest.json`)
2. Set `"active_pack": "<name>"` in config.json
3. Run `bash scripts/download-sounds.sh ~/.claude/hooks/peon-ping <name>`

Coming soon: Human Peasant ("Job's done!"), Night Elf Wisp, Undead Acolyte.

## Uninstall

```bash
bash ~/.claude/hooks/peon-ping/uninstall.sh
```

## Requirements

- macOS (uses `afplay` and AppleScript)
- Claude Code with hooks support
- python3

## How it works

`peon.sh` is a Claude Code hook registered for `SessionStart`, `UserPromptSubmit`, `Stop`, and `Notification` events. On each event it maps to a sound category, picks a random voice line (avoiding repeats), plays it via `afplay`, and updates your Terminal tab title.

Sound files are property of Blizzard Entertainment and are downloaded separately at install time from [The Sounds Resource](https://www.sounds-resource.com/).

## Links

- [Landing page](https://peon-ping.vercel.app/)
- [License (MIT)](LICENSE)
