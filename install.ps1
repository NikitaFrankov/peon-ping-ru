# peon-ping Windows Installer
# Native Windows port - plays Warcraft III Peon sounds when Claude Code needs attention
# Usage: powershell -ExecutionPolicy Bypass -File install.ps1

param(
    [Parameter()]
    $Packs = @(),
    [switch]$All,
    [switch]$Local
)

# When run via Invoke-Expression (one-liner install), $PSScriptRoot is empty.
$ScriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { $PWD.Path }
$ErrorActionPreference = "Stop"

Write-Host "=== peon-ping Windows installer ===" -ForegroundColor Cyan
Write-Host ""

# --- Paths ---
$GlobalClaudeDir = Join-Path $env:USERPROFILE ".claude"
$LocalClaudeDir = Join-Path $PWD.Path ".claude"

if ($Local) {
    $BaseDir = $LocalClaudeDir
    Write-Host "Local mode enabled. Installing to $BaseDir" -ForegroundColor Yellow
} else {
    $BaseDir = $GlobalClaudeDir
}

$InstallDir = Join-Path $BaseDir "hooks\peon-ping"
$SettingsFile = Join-Path $BaseDir "settings.json"
$RepoBase = "https://raw.githubusercontent.com/NikitaFrankov/peon-ping-ru/main"

# --- Detect update vs fresh install ---
$Updating = $false
if (Test-Path (Join-Path $InstallDir "peon.ps1")) {
    $Updating = $true
    Write-Host "Existing install found. Updating..." -ForegroundColor Yellow
}

if (-not (Test-Path $BaseDir)) {
    if ($Local) {
        Write-Host "Error: .claude directory not found in current project." -ForegroundColor Red
        exit 1
    }
    New-Item -ItemType Directory -Path $BaseDir -Force | Out-Null
}

# --- Create directories ---
New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
$scriptsDir = Join-Path $InstallDir "scripts"
$trainerDir = Join-Path $InstallDir "trainer"
New-Item -ItemType Directory -Path $scriptsDir -Force | Out-Null
New-Item -ItemType Directory -Path $trainerDir -Force | Out-Null

# --- Helper: Sync file (Local vs Remote) ---
function Sync-PeonFile($name, $targetPath) {
    $localFile = Join-Path $ScriptDir $name
    if (Test-Path $localFile) {
        if ($localFile -eq $targetPath) { return }
        Copy-Item -Path $localFile -Destination $targetPath -Force
    } else {
        $url = "$RepoBase/$name"
        try {
            Invoke-WebRequest -Uri $url -OutFile $targetPath -UseBasicParsing -ErrorAction Stop
        } catch {
            Write-Host "  Warning: Could not download $name" -ForegroundColor Yellow
        }
    }
}

# --- Install Core Scripts ---
Write-Host "Installing core scripts..." -ForegroundColor White
Sync-PeonFile "peon.ps1" (Join-Path $InstallDir "peon.ps1")
Sync-PeonFile "scripts/win-play.ps1" (Join-Path $scriptsDir "win-play.ps1")
Sync-PeonFile "scripts/win-notify.ps1" (Join-Path $scriptsDir "win-notify.ps1")
Sync-PeonFile "scripts/pack-download.ps1" (Join-Path $scriptsDir "pack-download.ps1")
Sync-PeonFile "scripts/hook-handle-use.ps1" (Join-Path $scriptsDir "hook-handle-use.ps1")
Sync-PeonFile "VERSION" (Join-Path $InstallDir "VERSION")
Sync-PeonFile "uninstall.ps1" (Join-Path $InstallDir "uninstall.ps1")

# --- Download packs via shared engine ---
Write-Host "Downloading sound packs..." -ForegroundColor White
$packDlScript = Join-Path $scriptsDir "pack-download.ps1"
if (Test-Path $packDlScript) {
    if ($All) { 
        & $packDlScript -Dir $InstallDir -All
    } elseif ($Packs -and $Packs.Count -gt 0) {
        $csv = if ($Packs -is [array]) { $Packs -join ',' } else { $Packs }
        & $packDlScript -Dir $InstallDir -PacksCsv $csv
    } else {
        & $packDlScript -Dir $InstallDir -PacksCsv "peonRu,peasantRu"
    }
}

# --- Install trainer voice packs ---
Write-Host "Installing trainer voice packs..." -ForegroundColor White
$trainerSourceDir = Join-Path $ScriptDir "trainer"
if (Test-Path $trainerSourceDir) {
    Copy-Item -Path (Join-Path $trainerSourceDir "manifest.json") -Destination $trainerDir -Force
    $soundsSource = Join-Path $trainerSourceDir "sounds"
    if (Test-Path $soundsSource) {
        Copy-Item -Path $soundsSource -Destination $trainerDir -Recurse -Force
    }
} else {
    try {
        $manifestUrl = "$RepoBase/trainer/manifest.json"
        $manifestFile = Join-Path $trainerDir "manifest.json"
        Invoke-WebRequest -Uri $manifestUrl -OutFile $manifestFile -UseBasicParsing -ErrorAction Stop
        
        $tm = Get-Content $manifestFile | ConvertFrom-Json
        foreach ($prop in $tm.PSObject.Properties) {
            foreach ($s in $prop.Value) {
                $sfile = $s.file
                $target = Join-Path $trainerDir $sfile
                $parent = Split-Path $target -Parent
                if (-not (Test-Path $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
                Invoke-WebRequest -Uri "$RepoBase/trainer/$sfile" -OutFile $target -UseBasicParsing -ErrorAction SilentlyContinue
            }
        }
    } catch {
        Write-Host "  Warning: Could not download trainer packs" -ForegroundColor Yellow
    }
}

# --- Handle Config (Mirroring install.sh logic) ---
$configPath = Join-Path $InstallDir "config.json"
$configTemplatePath = Join-Path $InstallDir "config.json.template"

# Get the latest config from the repo
Sync-PeonFile "config.json" $configTemplatePath

if (Test-Path $configPath) {
    # Update existing config with new keys
    try {
        $userCfg = Get-Content $configPath -Raw | ConvertFrom-Json
        $templateCfg = Get-Content $configTemplatePath -Raw | ConvertFrom-Json
        
        $changed = $false
        foreach ($prop in $templateCfg.PSObject.Properties) {
            if (-not $userCfg.PSObject.Properties[$prop.Name]) {
                $userCfg | Add-Member -NotePropertyName $prop.Name -NotePropertyValue $prop.Value
                $changed = $true
            }
        }
        
        if ($changed) {
            $userCfg | ConvertTo-Json -Depth 10 | Set-Content $configPath -Encoding UTF8
            Write-Host "Config updated with new keys from repository." -ForegroundColor DarkGray
        }
    } catch {
        Write-Host "  Warning: Could not merge config updates." -ForegroundColor Yellow
    }
} else {
    # Clean install: use the template as config
    Copy-Item -Path $configTemplatePath -Destination $configPath -Force
}
# Cleanup template
if (Test-Path $configTemplatePath) { Remove-Item $configTemplatePath -Force }

# --- Initialize state ---
$statePath = Join-Path $InstallDir ".state.json"
if (-not (Test-Path $statePath)) {
    Set-Content -Path $statePath -Value "{}" -Encoding UTF8
}

# --- Install skills ---
Write-Host "Installing skills..." -ForegroundColor White
$skillsSourceDir = Join-Path $ScriptDir "skills"
$skillsTargetDir = Join-Path $BaseDir "skills"
New-Item -ItemType Directory -Path $skillsTargetDir -Force | Out-Null

$skillNames = @("peon-ping-toggle", "peon-ping-config", "peon-ping-use", "peon-ping-log")
foreach ($skillName in $skillNames) {
    $skillTarget = Join-Path $skillsTargetDir $skillName
    $skillSource = Join-Path $skillsSourceDir $skillName
    if (Test-Path $skillSource) {
        if (Test-Path $skillTarget) { Remove-Item -Path $skillTarget -Recurse -Force }
        Copy-Item -Path $skillSource -Destination $skillTarget -Recurse -Force
        Write-Host "  /$skillName" -ForegroundColor DarkGray
    } else {
        New-Item -ItemType Directory -Path $skillTarget -Force | Out-Null
        $skillUrl = "$RepoBase/skills/$skillName/SKILL.md"
        try { Invoke-WebRequest -Uri $skillUrl -OutFile (Join-Path $skillTarget "SKILL.md") -UseBasicParsing -ErrorAction SilentlyContinue } catch {}
    }
}

# --- Register Hooks in settings.json ---
Write-Host "Registering Claude Code hooks..."
if (Test-Path $SettingsFile) {
    try {
        $settings = Get-Content $SettingsFile -Raw | ConvertFrom-Json
        if (-not ($settings.PSObject.Properties['hooks'])) { $settings | Add-Member -NotePropertyName "hooks" -NotePropertyValue (New-Object PSCustomObject) }
        $hookPath = Join-Path $InstallDir "peon.ps1"
        $hookCmd = "powershell -NoProfile -NonInteractive -ExecutionPolicy Bypass -File `"$hookPath`""
        $events = @("SessionStart", "SessionEnd", "SubagentStart", "Stop", "Notification", "PermissionRequest", "PostToolUseFailure", "PreCompact")
        foreach ($evt in $events) {
            $peonHook = [PSCustomObject]@{ type = "command"; command = $hookCmd; timeout = 10 }
            $entry = [PSCustomObject]@{ matcher = ""; hooks = @($peonHook) }
            $existing = if ($settings.hooks.PSObject.Properties[$evt]) { @($settings.hooks.$evt) } else { @() }
            $filtered = $existing | Where-Object { 
                $keep = $true
                if ($_.hooks) { foreach ($h in $_.hooks) { if ($h.command -match "peon") { $keep = $false } } }
                $keep
            }
            $settings.hooks | Add-Member -NotePropertyName $evt -NotePropertyValue @($filtered + $entry) -Force
        }
        # UserPromptSubmit
        $useHookPath = Join-Path $scriptsDir "hook-handle-use.ps1"
        $useCmd = "powershell -NoProfile -NonInteractive -ExecutionPolicy Bypass -File `"$useHookPath`""
        $useEntry = [PSCustomObject]@{ matcher = ""; hooks = @([PSCustomObject]@{ type = "command"; command = $useCmd; timeout = 5 }) }
        $existingUse = if ($settings.hooks.PSObject.Properties["UserPromptSubmit"]) { @($settings.hooks.UserPromptSubmit) } else { @() }
        $filteredUse = $existingUse | Where-Object {
            $keep = $true
            if ($_.hooks) { foreach ($h in $_.hooks) { if ($h.command -match "hook-handle-use") { $keep = $false } } }
            $keep
        }
        $settings.hooks | Add-Member -NotePropertyName "UserPromptSubmit" -NotePropertyValue @($filteredUse + $useEntry) -Force
        $settings | ConvertTo-Json -Depth 10 | Set-Content $SettingsFile -Encoding UTF8
        Write-Host "Hooks registered for Claude Code." -ForegroundColor Green
    } catch {}
}

# --- Install CLI shortcut ---
if (-not $Local) {
    $cliBinDir = Join-Path $env:USERPROFILE ".local\bin"
    if (-not (Test-Path $cliBinDir)) { New-Item -ItemType Directory -Path $cliBinDir -Force | Out-Null }
    $batContent = "@echo off`npowershell -NoProfile -ExecutionPolicy Bypass -File `"$InstallDir\peon.ps1`" %*"
    Set-Content -Path (Join-Path $cliBinDir "peon.cmd") -Value $batContent
    $userPath = [Environment]::GetEnvironmentVariable("PATH", "User")
    if ($userPath -notlike "*$cliBinDir*") {
        [Environment]::SetEnvironmentVariable("PATH", "$userPath;$cliBinDir", "User")
        Write-Host "Added $cliBinDir to PATH." -ForegroundColor Green
    }
}

# --- Test sound ---
Write-Host "Testing sound..." -ForegroundColor White
$testCfg = Get-Content $configPath -Raw | ConvertFrom-Json
$testPackDir = Join-Path $InstallDir "packs\$($testCfg.active_pack)\sounds"
$testSound = Get-ChildItem -Path $testPackDir -File -ErrorAction SilentlyContinue | Select-Object -First 1
if ($testSound) {
    $winPlayScript = Join-Path $scriptsDir "win-play.ps1"
    if (Test-Path $winPlayScript) {
        Start-Process -WindowStyle Hidden -FilePath "powershell.exe" -ArgumentList "-NoProfile","-ExecutionPolicy","Bypass","-File",$winPlayScript,"-path",$testSound.FullName,"-vol",0.3
    }
}

# --- Final Summary ---
Write-Host ""
if ($Updating) { Write-Host "=== peon-ping updated! ===" -ForegroundColor Green } else { Write-Host "=== peon-ping installed! ===" -ForegroundColor Green }
Write-Host ""
$finalCfg = Get-Content $configPath -Raw | ConvertFrom-Json
Write-Host "  Active pack: $($finalCfg.active_pack)" -ForegroundColor Cyan
Write-Host "  Volume:      $($finalCfg.volume)" -ForegroundColor Cyan
Write-Host ""
& (Join-Path $InstallDir "peon.ps1") help
Write-Host ""
Write-Host "  Start Claude Code and you'll hear: `"Работа завершена, хозяин`"" -ForegroundColor Yellow
Write-Host ""
Write-Host "  Installer options:" -ForegroundColor DarkGray
Write-Host "    .\install.ps1 -Packs name1,name2  Install specific packs"
Write-Host "    .\install.ps1 -All                Install ALL available packs"
Write-Host "    .\install.ps1 -Local              Install to current project only"
Write-Host ""
Write-Host "  To uninstall: powershell -ExecutionPolicy Bypass -File `"$InstallDir\uninstall.ps1`"" -ForegroundColor DarkGray
Write-Host ""
