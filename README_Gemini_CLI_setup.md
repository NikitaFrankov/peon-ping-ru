# Setup: Linux, MacOS, WSL

1. Ensure peon-ping is installed
   ```bash
   curl -fsSL https://raw.githubusercontent.com/NikitaFrankov/peon-ping-ru/main/install.sh | bash
   ```
2. Copy adapter [gemini.sh](https://github.com/NikitaFrankov/peon-ping-ru/blob/main/adapters/gemini.sh) to `~/.claude/hooks/peon-ping/adapters/`
3. Add the following hooks to your `~/.gemini/settings.json`:

   ```json
    {
      "hooks": {
        "SessionStart": [
          {
            "matcher": "startup",
            "hooks": [
              {
                "name": "peon-start",
                "type": "command",
                "command": "bash ~/.claude/hooks/peon-ping/adapters/gemini.sh SessionStart"
              }
            ]
          }
        ],
        "AfterAgent": [
          {
            "matcher": "*",
            "hooks": [
              {
                "name": "peon-after-agent",
                "type": "command",
                "command": "bash ~/.claude/hooks/peon-ping/adapters/gemini.sh AfterAgent"
              }
            ]
          }
        ],
        "AfterTool": [
          {
            "matcher": "*",
            "hooks": [
              {
                "name": "peon-after-tool",
                "type": "command",
                "command": "bash ~/.claude/hooks/peon-ping/adapters/gemini.sh AfterTool"
              }
            ]
          }
        ],
        "Notification": [
          {
            "matcher": "*",
            "hooks": [
              {
                "name": "peon-notification",
                "type": "command",
                "command": "bash ~/.claude/hooks/peon-ping/adapters/gemini.sh Notification"
              }
            ]
          }
        ]
      }
    }
   ```

# Setup: Windows

1. Ensure peon-ping is installed
   ```powershell
   Invoke-WebRequest -Uri "https://raw.githubusercontent.com/NikitaFrankov/peon-ping-ru/main/install.ps1" -UseBasicParsing | Invoke-Expression
   ``` 
2. Copy adapter [gemini.ps1](https://github.com/NikitaFrankov/peon-ping-ru/blob/main/adapters/gemini.ps1) to  to `%USERPROFILE%\.claude\hooks\peon-ping\adapters\`
3. Add the following hooks to your `%USERPROFILE%/.gemini/settings.json`:

   ```json
    {
      "hooks": {
        "SessionStart": [
          {
            "matcher": "startup",
            "hooks": [
              {
                "name": "peon-start",
                "type": "command",
                "command": "powershell.exe -NoProfile -ExecutionPolicy Bypass -File \"$env:USERPROFILE\\.claude\\hooks\\peon-ping\\adapters\\gemini.ps1\" SessionStart"
              }
            ]
          }
        ],
        "AfterAgent": [
          {
            "matcher": "*",
            "hooks": [
              {
                "name": "peon-after-agent",
                "type": "command",
                "command": "powershell.exe -NoProfile -ExecutionPolicy Bypass -File \"$env:USERPROFILE\\.claude\\hooks\\peon-ping\\adapters\\gemini.ps1\" AfterAgent"
              }
            ]
          }
        ],
        "AfterTool": [
          {
            "matcher": "*",
            "hooks": [
              {
                "name": "peon-after-tool",
                "type": "command",
                "command": "powershell.exe -NoProfile -ExecutionPolicy Bypass -File \"$env:USERPROFILE\\.claude\\hooks\\peon-ping\\adapters\\gemini.ps1\" AfterTool"
              }
            ]
          }
        ],
        "Notification": [
          {
            "matcher": "*",
            "hooks": [
              {
                "name": "peon-notification",
                "type": "command",
                "command": "powershell.exe -NoProfile -ExecutionPolicy Bypass -File \"$env:USERPROFILE\\.claude\\hooks\\peon-ping\\adapters\\gemini.ps1\" Notification"
              }
            ]
          }
        ]
      }
    }
   ```
   
**Event mapping:**

- `SessionStart` (startup) → Greeting sound (*"Ready to work?"*, *"Yes?"*)
- `AfterAgent` → Task completion sound (*"Work, work."*, *"Job's done!"*)
- `AfterTool` → Success = Task completion sound, Failure = Error sound (*"I can't do that."*)
- `Notification` → System notification
