# peon-ping adapter for Gemini CLI (Windows PowerShell)
# Translates Gemini CLI hook events into peon.ps1 stdin JSON

param(
    [string]$GeminiEventType = "SessionStart"
)

# Path to peon.ps1
$InstallDir = if ($env:CLAUDE_PEON_DIR) { $env:CLAUDE_PEON_DIR } else { Join-Path $env:USERPROFILE ".claude\hooks\peon-ping" }
$PeonPath = Join-Path $InstallDir "peon.ps1"

# Read JSON from stdin
$inputJSON = $input | Out-String
$inputData = $null

if ($inputJSON) {
    try {
        $inputData = $inputJSON | ConvertFrom-Json
    } catch {
        # Invalid JSON, ignore
    }
}

$sessionId = if ($inputData -and $inputData.session_id) { $inputData.session_id } else { "gemini-$PID" }
$cwd = if ($inputData -and $inputData.cwd) { $inputData.cwd } else { $PWD.Path }

$event = ""
$toolName = ""
$errorMsg = ""

switch ($GeminiEventType) {
    "SessionStart" { $event = "SessionStart" }
    "AfterAgent"   { $event = "Stop" }
    "Notification" { $event = "Notification" }
    "AfterTool" {
        if ($inputData.exit_code -ne 0) {
            $event = "PostToolUseFailure"
            $toolName = if ($inputData.tool_name) { $inputData.tool_name } else { "unknown" }
            $errorMsg = if ($inputData.stderr) { $inputData.stderr } else { "Tool failed" }
        } else {
            $event = "Stop"
        }
    }
    Default {
        Write-Output "{}"
        exit 0
    }
}

if ($event) {
    $payload = @{
        hook_event_name = $event
        notification_type = ""
        cwd = $cwd
        session_id = $sessionId
        permission_mode = ""
        tool_name = $toolName
        error = $errorMsg
    } | ConvertTo-Json -Compress

    # Pipe to peon.ps1
    $payload | powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $PeonPath > $null 2>&1
}

# Always return valid empty JSON to Gemini CLI
Write-Output "{}"
