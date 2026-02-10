#!/bin/bash
# peon-ping installer
# Works both via `curl | bash` (downloads from GitHub) and local clone
# Re-running updates core files without re-downloading sounds
set -euo pipefail

INSTALL_DIR="$HOME/.claude/hooks/peon-ping"
SETTINGS="$HOME/.claude/settings.json"
REPO_BASE="https://raw.githubusercontent.com/tonyyont/peon-ping/main"

# --- Detect update vs fresh install ---
UPDATING=false
if [ -f "$INSTALL_DIR/peon.sh" ] && [ -d "$INSTALL_DIR/packs/peon/sounds" ]; then
  SOUND_COUNT=$(ls "$INSTALL_DIR/packs/peon/sounds/"*.wav 2>/dev/null | wc -l | tr -d ' ')
  if [ "$SOUND_COUNT" -gt 0 ]; then
    UPDATING=true
  fi
fi

if [ "$UPDATING" = true ]; then
  echo "=== peon-ping updater ==="
  echo ""
  echo "Existing install found. Updating core files (sounds preserved)..."
else
  echo "=== peon-ping installer ==="
  echo ""
fi

# --- Prerequisites ---
if [ "$(uname)" != "Darwin" ]; then
  echo "Error: peon-ping requires macOS (uses afplay + AppleScript)"
  exit 1
fi

if ! command -v python3 &>/dev/null; then
  echo "Error: python3 is required"
  exit 1
fi

if ! command -v afplay &>/dev/null; then
  echo "Error: afplay is required (should be built into macOS)"
  exit 1
fi

if [ ! -d "$HOME/.claude" ]; then
  echo "Error: ~/.claude/ not found. Is Claude Code installed?"
  exit 1
fi

# --- Detect if running from local clone or curl|bash ---
SCRIPT_DIR=""
if [ -n "${BASH_SOURCE[0]:-}" ] && [ "${BASH_SOURCE[0]}" != "bash" ]; then
  CANDIDATE="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)"
  if [ -f "$CANDIDATE/peon.sh" ]; then
    SCRIPT_DIR="$CANDIDATE"
  fi
fi

# --- Install/update core files ---
mkdir -p "$INSTALL_DIR"/{packs/peon,scripts}

if [ -n "$SCRIPT_DIR" ]; then
  # Local clone — copy files directly
  cp -r "$SCRIPT_DIR/packs/"* "$INSTALL_DIR/packs/"
  cp "$SCRIPT_DIR/scripts/download-sounds.sh" "$INSTALL_DIR/scripts/"
  cp "$SCRIPT_DIR/peon.sh" "$INSTALL_DIR/"
  # Only overwrite config on fresh install (preserve user customizations)
  if [ "$UPDATING" = false ]; then
    cp "$SCRIPT_DIR/config.json" "$INSTALL_DIR/"
  fi
else
  # curl|bash — download from GitHub
  echo "Downloading from GitHub..."
  curl -fsSL "$REPO_BASE/peon.sh" -o "$INSTALL_DIR/peon.sh"
  curl -fsSL "$REPO_BASE/packs/peon/manifest.json" -o "$INSTALL_DIR/packs/peon/manifest.json"
  curl -fsSL "$REPO_BASE/scripts/download-sounds.sh" -o "$INSTALL_DIR/scripts/download-sounds.sh"
  curl -fsSL "$REPO_BASE/uninstall.sh" -o "$INSTALL_DIR/uninstall.sh"
  # Only overwrite config on fresh install (preserve user customizations)
  if [ "$UPDATING" = false ]; then
    curl -fsSL "$REPO_BASE/config.json" -o "$INSTALL_DIR/config.json"
  fi
fi

chmod +x "$INSTALL_DIR/peon.sh"
chmod +x "$INSTALL_DIR/scripts/download-sounds.sh"

# --- Download sounds (skip on update if already present) ---
if [ "$UPDATING" = false ]; then
  echo ""
  bash "$INSTALL_DIR/scripts/download-sounds.sh" "$INSTALL_DIR" "peon"
else
  echo "Sounds already installed ($SOUND_COUNT files) — skipped."
fi

# --- Backup existing notify.sh (fresh install only) ---
if [ "$UPDATING" = false ]; then
  NOTIFY_SH="$HOME/.claude/hooks/notify.sh"
  if [ -f "$NOTIFY_SH" ]; then
    cp "$NOTIFY_SH" "$NOTIFY_SH.backup"
    echo ""
    echo "Backed up notify.sh → notify.sh.backup"
  fi
fi

# --- Update settings.json ---
echo ""
echo "Updating Claude Code hooks in settings.json..."

/usr/bin/python3 -c "
import json, os, sys

settings_path = os.path.expanduser('~/.claude/settings.json')
hook_cmd = os.path.expanduser('~/.claude/hooks/peon-ping/peon.sh')

# Load existing settings
if os.path.exists(settings_path):
    with open(settings_path) as f:
        settings = json.load(f)
else:
    settings = {}

hooks = settings.setdefault('hooks', {})

peon_hook = {
    'type': 'command',
    'command': hook_cmd,
    'timeout': 10
}

peon_entry = {
    'matcher': '',
    'hooks': [peon_hook]
}

# Events to register
events = ['SessionStart', 'UserPromptSubmit', 'Stop', 'Notification']

for event in events:
    event_hooks = hooks.get(event, [])
    # Remove any existing notify.sh or peon.sh entries
    event_hooks = [
        h for h in event_hooks
        if not any(
            'notify.sh' in hk.get('command', '') or 'peon.sh' in hk.get('command', '')
            for hk in h.get('hooks', [])
        )
    ]
    event_hooks.append(peon_entry)
    hooks[event] = event_hooks

settings['hooks'] = hooks

with open(settings_path, 'w') as f:
    json.dump(settings, f, indent=2)
    f.write('\n')

print('Hooks registered for: ' + ', '.join(events))
"

# --- Initialize state (fresh install only) ---
if [ "$UPDATING" = false ]; then
  echo '{}' > "$INSTALL_DIR/.state.json"
fi

# --- Test sound ---
echo ""
echo "Testing sound..."
PACK_DIR="$INSTALL_DIR/packs/peon"
TEST_SOUND=$(ls "$PACK_DIR/sounds/"*.wav 2>/dev/null | head -1)
if [ -n "$TEST_SOUND" ]; then
  afplay -v 0.3 "$TEST_SOUND"
  echo "Sound working!"
else
  echo "Warning: No sound files found. Sounds may not play."
fi

echo ""
if [ "$UPDATING" = true ]; then
  echo "=== Update complete! ==="
  echo ""
  echo "Updated: peon.sh, manifest.json"
  echo "Preserved: config.json, sounds, state"
else
  echo "=== Installation complete! ==="
  echo ""
  echo "Config: $INSTALL_DIR/config.json"
  echo "  - Adjust volume, toggle categories, switch packs"
  echo ""
  echo "Uninstall: bash $INSTALL_DIR/uninstall.sh"
fi
echo ""
echo "Ready to work!"
