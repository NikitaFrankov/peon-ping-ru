# peon-ping hook for Claude Code (Windows native)
# Called by Claude Code hooks on SessionStart, Stop, Notification, PermissionRequest, PostToolUseFailure, PreCompact

param(
    [string]$Command = "",
    [string]$Arg1 = "",
    [string]$Arg2 = "",
    [string]$Arg3 = ""
)

# Helper to normalize arguments
$CliCommand = $Command
$CliArg = $Arg1
$CliArg2 = $Arg2
$CliArg3 = $Arg3
if (-not $CliCommand -and $args.Count -gt 0) {
    $CliCommand = $args[0]
    if ($args.Count -gt 1) { $CliArg = $args[1] }
    if ($args.Count -gt 2) { $CliArg2 = $args[2] }
    if ($args.Count -gt 3) { $CliArg3 = $args[3] }
}

$NormalCmd = if ($CliCommand) { $CliCommand.TrimStart('-') } else { "" }

function Test-TerminalFocused {
    try {
        $signature = '[DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();'
        $type = Add-Type -MemberDefinition $signature -Name "Win32Focus" -Namespace "Win32" -PassThru
        $hwnd = $type::GetForegroundWindow()
        if ($hwnd -eq [IntPtr]::Zero) { return $false }
        $process = Get-Process | Where-Object { $_.MainWindowHandle -eq $hwnd }
        if ($null -eq $process) { return $false }
        $procName = $process.ProcessName.ToLower()
        $terminals = @("powershell", "pwsh", "cmd", "windowsterminal", "cursor", "code", "windsurf", "idea64", "webstorm", "ghostty", "iterm")
        foreach ($term in $terminals) { if ($procName -like "*$term*") { return $true } }
    } catch {}
    return $false
}

function Save-PeonState {
    param($path, $obj)
    try {
        $json = $obj | ConvertTo-Json -Depth 10
        if ($json -and $json -ne "null") {
            Set-Content -Path $path -Value $json -Encoding UTF8 -Force
        }
    } catch {}
}

# --- CLI commands ---
if ($CliCommand -and ($NormalCmd -match "^(status|pause|resume|toggle|packs|pack|volume|notifications|trainer|help)$")) {
    $InstallDir = Split-Path -Parent $MyInvocation.MyCommand.Path
    $ConfigPath = Join-Path $InstallDir "config.json"
    $StatePath = Join-Path $InstallDir ".state.json"
    $ScriptsDir = Join-Path $InstallDir "scripts"

    if (-not (Test-Path $ConfigPath)) { Write-Host "Error: Config not found" -ForegroundColor Red; exit 1 }
    $state = if (Test-Path $StatePath) { 
        $raw = Get-Content $StatePath -Raw
        if ($raw -match "\{") { $raw | ConvertFrom-Json } else { New-Object PSCustomObject }
    } else { New-Object PSCustomObject }

    switch ($NormalCmd) {
        "toggle" {
            $cfg = Get-Content $ConfigPath -Raw | ConvertFrom-Json
            $cfg | Add-Member -NotePropertyName "enabled" -NotePropertyValue (-not $cfg.enabled) -Force
            $cfg | ConvertTo-Json -Depth 10 | Set-Content $ConfigPath -Encoding UTF8
            Write-Host "peon-ping: $(if ($cfg.enabled) { 'ENABLED' } else { 'PAUSED' })" -ForegroundColor Cyan
        }
        "pause" {
            $cfg = Get-Content $ConfigPath -Raw | ConvertFrom-Json
            $cfg | Add-Member -NotePropertyName "enabled" -NotePropertyValue $false -Force
            $cfg | ConvertTo-Json -Depth 10 | Set-Content $ConfigPath -Encoding UTF8
            Write-Host "peon-ping: PAUSED" -ForegroundColor Yellow
        }
        "resume" {
            $cfg = Get-Content $ConfigPath -Raw | ConvertFrom-Json
            $cfg | Add-Member -NotePropertyName "enabled" -NotePropertyValue $true -Force
            $cfg | ConvertTo-Json -Depth 10 | Set-Content $ConfigPath -Encoding UTF8
            Write-Host "peon-ping: ENABLED" -ForegroundColor Green
        }
        "status" {
            $cfg = Get-Content $ConfigPath -Raw | ConvertFrom-Json
            $s = if ($cfg.enabled) { "ENABLED" } else { "PAUSED" }
            $active = if ($cfg.default_pack) { $cfg.default_pack } else { $cfg.active_pack }
            $style = if ($cfg.notification_style) { $cfg.notification_style } else { "standard" }
            Write-Host "peon-ping: $s | pack: $active | volume: $($cfg.volume) | style: $style | trainer: $(if ($cfg.trainer.enabled) { 'ON' } else { 'OFF' })" -ForegroundColor Cyan
        }
        "packs" {
            if ($CliArg -eq "list" -and $CliArg2 -match "registry") {
                & (Join-Path $ScriptsDir "pack-download.ps1") -Dir $InstallDir -ListRegistry; return
            }
            if ($CliArg -eq "install") {
                if ($CliArg2 -eq "all") { & (Join-Path $ScriptsDir "pack-download.ps1") -Dir $InstallDir -All }
                elseif ($CliArg2) { & (Join-Path $ScriptsDir "pack-download.ps1") -Dir $InstallDir -PacksCsv $CliArg2 }
                return
            }
            $cfg = Get-Content $ConfigPath -Raw | ConvertFrom-Json
            $active = if ($cfg.default_pack) { $cfg.default_pack } else { $cfg.active_pack }
            Write-Host "Available packs:" -ForegroundColor Cyan
            Get-ChildItem -Path (Join-Path $InstallDir "packs") -Directory | ForEach-Object {
                $c = (Get-ChildItem -Path (Join-Path $_.FullName "sounds") -File -ErrorAction SilentlyContinue).Count
                if ($c -gt 0) { Write-Host "  $($_.Name) ($c sounds)$(if ($_.Name -eq $active) { ' <-- active' })" }
            }
        }
        "pack" {
            $cfg = Get-Content $ConfigPath -Raw | ConvertFrom-Json
            if ($CliArg) {
                $newPack = $CliArg.TrimStart('-')
                if ($CliArg2 -match "install") { & (Join-Path $ScriptsDir "pack-download.ps1") -Dir $InstallDir -PacksCsv $newPack }
                if (-not (Test-Path (Join-Path $InstallDir "packs\$newPack"))) { Write-Host "Error: pack not found" -ForegroundColor Red; return }
            } else {
                $active = if ($cfg.default_pack) { $cfg.default_pack } else { $cfg.active_pack }
                $avail = Get-ChildItem -Path (Join-Path $InstallDir "packs") -Directory | Where-Object { (Get-ChildItem -Path (Join-Path $_.FullName "sounds") -File -ErrorAction SilentlyContinue).Count -gt 0 } | ForEach-Object { $_.Name } | Sort-Object
                $newPack = $avail[([array]::IndexOf($avail, $active) + 1) % $available.Count]
            }
            if ($cfg.default_pack) { $cfg | Add-Member -NotePropertyName "default_pack" -NotePropertyValue $newPack -Force }
            else { $cfg | Add-Member -NotePropertyName "active_pack" -NotePropertyValue $newPack -Force }
            $cfg | ConvertTo-Json -Depth 10 | Set-Content $ConfigPath -Encoding UTF8
            Write-Host "peon-ping: switched to '$newPack'" -ForegroundColor Green
        }
        "volume" {
            if ($CliArg) {
                $cfg = Get-Content $ConfigPath -Raw | ConvertFrom-Json
                $vol = [math]::Max(0, [math]::Min(1, [double]$CliArg))
                $cfg | Add-Member -NotePropertyName "volume" -NotePropertyValue $vol -Force
                $cfg | ConvertTo-Json -Depth 10 | Set-Content $ConfigPath -Encoding UTF8
                Write-Host "peon-ping: volume set to $($cfg.volume)" -ForegroundColor Green
            }
        }
        "notifications" {
            $cfg = Get-Content $ConfigPath -Raw | ConvertFrom-Json
            $sub = if ($CliArg) { $CliArg.TrimStart('-') } else { "" }
            switch ($sub) {
                "on" { $cfg | Add-Member -NotePropertyName "desktop_notifications" -NotePropertyValue $true -Force }
                "off" { $cfg | Add-Member -NotePropertyName "desktop_notifications" -NotePropertyValue $false -Force }
                "overlay" { $cfg | Add-Member -NotePropertyName "notification_style" -NotePropertyValue "overlay" -Force }
                "standard" { $cfg | Add-Member -NotePropertyName "notification_style" -NotePropertyValue "standard" -Force }
                "test" {
                    if ($cfg.desktop_notifications -eq $false) {
                        Write-Host "peon-ping: уведомления выключены (выполните 'peon notifications on' чтобы включить)" -ForegroundColor Red
                        return
                    }
                    $notifStyle = if ($cfg.notification_style) { $cfg.notification_style } else { "standard" }
                    $active = if ($cfg.default_pack) { $cfg.default_pack } else { $cfg.active_pack }
                    if (-not $active) { $active = "peonRu" }
                    $testIconPath = ""
                    $pDir = Join-Path $InstallDir "packs\$active"
                    if (Test-Path (Join-Path $pDir "openpeon.json")) {
                        $m = Get-Content (Join-Path $pDir "openpeon.json") -Raw | ConvertFrom-Json
                        $iCan = if ($m.icon) { $m.icon } else { "icon.png" }
                        $res = [System.IO.Path]::GetFullPath((Join-Path $pDir $iCan))
                        if (Test-Path $res) { $testIconPath = $res }
                    }
                    Write-Host "peon-ping: отправка тестового уведомления (стиль: $notifStyle)..." -ForegroundColor Cyan
                    & (Join-Path $ScriptsDir "win-notify.ps1") -Msg "Это тестовое уведомление" -Title "peon-ping test" -Color "blue" -Style $notifStyle -IconPath $testIconPath
                    return
                }
            }
            $cfg | ConvertTo-Json -Depth 10 | Set-Content $ConfigPath -Encoding UTF8
            $finalStyle = if ($cfg.notification_style) { $cfg.notification_style } else { "standard" }
            Write-Host "peon-ping: notifications style set to $finalStyle" -ForegroundColor Green
        }
        "trainer" {
            $cfg = Get-Content $ConfigPath -Raw | ConvertFrom-Json
            if (-not $state.trainer) { $state | Add-Member -NotePropertyName "trainer" -NotePropertyValue (New-Object PSCustomObject) }
            if (-not $state.trainer.reps) { $state.trainer | Add-Member -NotePropertyName "reps" -NotePropertyValue (New-Object PSCustomObject) }
            $today = (Get-Date).ToString("yyyy-MM-dd")
            if ($state.trainer.date -ne $today) {
                $state.trainer | Add-Member -NotePropertyName "date" -NotePropertyValue $today -Force
                $state.trainer | Add-Member -NotePropertyName "reps" -NotePropertyValue (New-Object PSCustomObject) -Force
                foreach ($ex in $cfg.trainer.exercises.PSObject.Properties.Name) { $state.trainer.reps | Add-Member -NotePropertyName $ex -NotePropertyValue 0 }
            }
            switch ($CliArg.TrimStart('-')) {
                "on" { $cfg.trainer | Add-Member -NotePropertyName "enabled" -NotePropertyValue $true -Force; Write-Host "Trainer ON" -ForegroundColor Green }
                "off" { $cfg.trainer | Add-Member -NotePropertyName "enabled" -NotePropertyValue $false -Force; Write-Host "Trainer OFF" -ForegroundColor Yellow }
                "status" {
                    Write-Host "peon-ping: trainer status ($today)" -ForegroundColor Cyan
                    foreach ($ex in $cfg.trainer.exercises.PSObject.Properties.Name) {
                        $done = if ($state.trainer.reps.PSObject.Properties[$ex]) { $state.trainer.reps.$ex } else { 0 }
                        $goal = $cfg.trainer.exercises.$ex
                        $pct = if ($goal -gt 0) { [math]::Min(100, [math]::Floor(($done / $goal) * 100)) } else { 0 }
                        $bar = ("#" * [math]::Floor($pct / 10)) + ("-" * (10 - [math]::Floor($pct / 10)))
                        Write-Host "  $($ex): [$bar] $done/$goal ($pct%)"
                    }
                }
                "log" {
                    if ($CliArg2 -and $CliArg3) {
                        $num = [int]$CliArg2; $ex = $CliArg3
                        if (-not $state.trainer.reps.PSObject.Properties[$ex]) { $state.trainer.reps | Add-Member -NotePropertyName $ex -NotePropertyValue $num }
                        else { $state.trainer.reps.$ex += $num }
                        Write-Host "peon-ping: logged $num $ex" -ForegroundColor Green
                        if (Test-Path (Join-Path $InstallDir "trainer\manifest.json")) {
                            $tm = Get-Content (Join-Path $InstallDir "trainer\manifest.json") | ConvertFrom-Json
                            if ($tm.log) { $p = $tm.log | Get-Random; & (Join-Path $ScriptsDir "win-play.ps1") -path (Join-Path $InstallDir "trainer\$($p.file)") -vol $cfg.volume }
                        }
                    }
                }
                "goal" {
                    if ($CliArg3) { $cfg.trainer.exercises | Add-Member -NotePropertyName $CliArg2 -NotePropertyValue ([int]$CliArg3) -Force }
                    elseif ($CliArg2) { foreach ($ex in $cfg.trainer.exercises.PSObject.Properties.Name) { $cfg.trainer.exercises | Add-Member -NotePropertyName $ex -NotePropertyValue ([int]$CliArg2) -Force } }
                    Write-Host "Goal(s) updated" -ForegroundColor Green
                }
            }
            $cfg | ConvertTo-Json -Depth 10 | Set-Content $ConfigPath -Encoding UTF8
        }
        "help" {
            Write-Host "peon-ping: Использование: peon <command> [args]" -ForegroundColor Cyan
            Write-Host ""
            Write-Host "Команды состояния:"
            Write-Host "  status         Показать текущий статус, пак и настройки"
            Write-Host "  pause          Приостановить все звуки и уведомления"
            Write-Host "  resume         Возобновить работу"
            Write-Host "  toggle         Переключить вкл/выкл"
            Write-Host ""
            Write-Host "Управление паками:"
            Write-Host "  packs list     Список установленных паков"
            Write-Host "  packs list registry  Список ВСЕХ доступных паков в облаке"
            Write-Host "  packs install <names|all>  Скачать паки (через запятую или 'all')"
            Write-Host "  pack [name]    Переключиться на пак (или на следующий)"
            Write-Host "  pack name install  Скачать и сразу включить пак"
            Write-Host ""
            Write-Host "Тренер (разминка):"
            Write-Host "  trainer on|off  Включить/выключить напоминания"
            Write-Host "  trainer status  Посмотреть прогресс за сегодня"
            Write-Host "  trainer log <n> <ex>  Записать упражнение (напр: log 20 pushups)"
            Write-Host "  trainer goal <n>      Установить цель на день"
            Write-Host ""
            Write-Host "Настройки:"
            Write-Host "  volume 0.5     Установить громкость (0.0 - 1.0)"
            Write-Host "  notifications  Настройка (on|off|overlay|standard|test)"
            Write-Host ""
            Write-Host "Для любой команды можно использовать '--' (напр: peon status)" -ForegroundColor Gray
        }
    }
    Save-PeonState $StatePath $state
    return
}

# --- Hook mode ---
$InstallDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ConfigPath = Join-Path $InstallDir "config.json"
$StatePath = Join-Path $InstallDir ".state.json"

try { $config = Get-Content $ConfigPath -Raw | ConvertFrom-Json } catch { exit 0 }
if (-not $config.enabled) { exit 0 }

$hookInput = ""
try { if ([Console]::In -and [Console]::IsInputRedirected) { $hookInput = [Console]::In.ReadToEnd() } } catch { exit 0 }
if (-not $hookInput) { exit 0 }
try { $event = $hookInput | ConvertFrom-Json } catch { exit 0 }

$hookEvent = $event.hook_event_name
if (-not $hookEvent) { exit 0 }
$cwd = if ($event.cwd) { $event.cwd } else { (Get-Location).Path }
$project = Split-Path $cwd -Leaf
if (-not $project) { $project = "claude" }

$status = ""; $marker = ""; $notifyColor = ""; $msg = ""; $isNotify = $false
$sessionId = if ($event.session_id) { $event.session_id } elseif ($event.conversation_id) { $event.conversation_id } else { "default" }

$state = if (Test-Path $StatePath) { 
    $raw = Get-Content $StatePath -Raw
    if ($raw -match "\{") { $raw | ConvertFrom-Json } else { New-Object PSCustomObject }
} else { New-Object PSCustomObject }

# --- Map Events ---
$category = $null
$ntype = $event.notification_type
switch ($hookEvent) {
    "SessionStart" { $category = "session.start"; $status = "ready" }
    "Stop" {
        $category = "task.complete"
        $now = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
        if ($state.last_stop_time -and ($now - $state.last_stop_time) -lt 5) { $category = $null }
        else {
            $state | Add-Member -NotePropertyName "last_stop_time" -NotePropertyValue $now -Force
            $status = "done"; $marker = "● "; $notifyColor = "blue"; $msg = "$project  —  Работа завершена, хозяин"; $isNotify = $true
        }
    }
    "Notification" {
        if ($ntype -eq "permission_prompt") { $status = "needs approval"; $marker = "● " }
        elseif ($ntype -eq "idle_prompt") { $status = "done"; $marker = "● "; $notifyColor = "yellow"; $msg = "$project  —  Че делать, хозяин?"; $isNotify = $true }
        else { $category = "task.complete"; $status = "done" }
    }
    "PermissionRequest" { $category = "input.required"; $status = "needs approval"; $marker = "● "; $notifyColor = "red"; $msg = "$project  —  Жду разрешения, хозяин"; $isNotify = $true }
    "UserPromptSubmit" { $status = "working" }
    "PostToolUseFailure" { $category = "task.error"; $status = "error" }
}

# Trainer Logic
$trainerSound = ""; $trainerMsg = ""
if ($config.trainer.enabled -and ($category -or $hookEvent -eq "SessionStart")) {
    $now = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
    if (-not $state.trainer) { $state | Add-Member -NotePropertyName "trainer" -NotePropertyValue (New-Object PSCustomObject) }
    if (-not $state.trainer.reps) { $state.trainer | Add-Member -NotePropertyName "reps" -NotePropertyValue (New-Object PSCustomObject) }
    $today = (Get-Date).ToString("yyyy-MM-dd")
    if ($state.trainer.date -ne $today) {
        $state.trainer | Add-Member -NotePropertyName "date" -NotePropertyValue $today -Force
        $state.trainer | Add-Member -NotePropertyName "reps" -NotePropertyValue (New-Object PSCustomObject) -Force
        foreach ($ex in $config.trainer.exercises.PSObject.Properties.Name) { $state.trainer.reps | Add-Member -NotePropertyName $ex -NotePropertyValue 0 }
    }
    $lastRemind = if ($state.trainer.last_reminder_ts) { $state.trainer.last_reminder_ts } else { 0 }
    $interval = if ($config.trainer.reminder_interval_minutes) { $config.trainer.reminder_interval_minutes * 60 } else { 1200 }
    if (($now - $lastRemind) -gt $interval -or $hookEvent -eq "SessionStart") {
        if (Test-Path (Join-Path $InstallDir "trainer\manifest.json")) {
            $tm = Get-Content (Join-Path $InstallDir "trainer\manifest.json") | ConvertFrom-Json
            $allDone = $true
            foreach ($ex in $config.trainer.exercises.PSObject.Properties.Name) { if ($state.trainer.reps.$ex -lt $config.trainer.exercises.$ex) { $allDone = $false; break } }
            $tcat = if ($hookEvent -eq "SessionStart") { "session_start" } elseif ($allDone) { "complete" } else { "remind" }
            if ($tm.$tcat) {
                $pick = $tm.$tcat | Get-Random; $trainerSound = Join-Path $InstallDir "trainer\$($pick.file)"
                $state.trainer | Add-Member -NotePropertyName "last_reminder_ts" -NotePropertyValue $now -Force; $trainerMsg = if ($allDone) { "Все упражнения выполнены!" } else { "Пора размяться!" }
            }
        }
    }
}

Save-PeonState $StatePath $state

if (-not $category -and -not $trainerSound) { exit 0 }

# Pick Sound
$soundPath = ""; $iconPath = ""
if ($category) {
    try {
        $activePack = if ($config.default_pack) { $config.default_pack } else { $config.active_pack }
        if (-not $activePack) { $activePack = "peonRu" }
        if ($config.pack_rotation_mode -eq "agentskill") {
            $sPacks = $state.session_packs
            if ($sPacks -and $sPacks.PSObject.Properties[$sessionId]) {
                $pData = $sPacks.$sessionId
                $candidate = if ($pData -is [hashtable]) { $pData.pack } else { $pData }
                if ($candidate -and (Test-Path (Join-Path $InstallDir "packs\$candidate"))) { $activePack = $candidate }
            }
        }
        $packDir = Join-Path $InstallDir "packs\$activePack"
        if (Test-Path (Join-Path $packDir "openpeon.json")) {
            $manifest = Get-Content (Join-Path $packDir "openpeon.json") -Raw | ConvertFrom-Json
            $catSounds = $manifest.categories.$category.sounds
            if ($catSounds) {
                $lastKey = "last_$category"
                $lastPlayed = if ($state.PSObject.Properties[$lastKey]) { $state.$lastKey } else { "" }
                $candidates = @($catSounds | Where-Object { (Split-Path $_.file -Leaf) -ne $lastPlayed })
                if ($candidates.Count -eq 0) { $candidates = @($catSounds) }
                $chosen = $candidates | Get-Random
                $soundPath = Join-Path $packDir "sounds\$(Split-Path $chosen.file -Leaf)"
                $state | Add-Member -NotePropertyName $lastKey -NotePropertyValue (Split-Path $chosen.file -Leaf) -Force
                Save-PeonState $StatePath $state
                $iconCandidate = if ($chosen.icon) { $chosen.icon } elseif ($manifest.categories.$category.icon) { $manifest.categories.$category.icon } elseif ($manifest.icon) { $manifest.icon } else { "icon.png" }
                $iconPath = [System.IO.Path]::GetFullPath((Join-Path $packDir $iconCandidate))
            }
        }
    } catch {}
}

# Play
$winPlayScript = Join-Path $InstallDir "scripts\win-play.ps1"
if (Test-Path $winPlayScript) {
    if ($soundPath -and (Test-Path $soundPath)) { Start-Process -WindowStyle Hidden -FilePath "powershell.exe" -ArgumentList "-NoProfile","-ExecutionPolicy","Bypass","-File",$winPlayScript,"-path",$soundPath,"-vol",$config.volume }
    if ($trainerSound -and (Test-Path $trainerSound)) { Start-Sleep -Seconds 2; Start-Process -WindowStyle Hidden -FilePath "powershell.exe" -ArgumentList "-NoProfile","-ExecutionPolicy","Bypass","-File",$winPlayScript,"-path",$trainerSound,"-vol",$config.volume }
}

# Notify
if ($config.desktop_notifications -ne $false -and -not (Test-TerminalFocused)) {
    $winNotifyScript = Join-Path $InstallDir "scripts\win-notify.ps1"
    if (Test-Path $winNotifyScript) {
        $notifStyle = if ($config.notification_style) { $config.notification_style } else { "standard" }
        if ($isNotify) { $title = "$marker$($project): $status"; Start-Process -WindowStyle Hidden -FilePath "powershell.exe" -ArgumentList "-NoProfile","-ExecutionPolicy","Bypass","-File",$winNotifyScript,"-Msg",("`"$msg`""),"-Title",("`"$title`""),"-Color",$notifyColor,"-Style",$notifStyle,"-IconPath",("`"$iconPath`"") }
        if ($trainerSound) { Start-Process -WindowStyle Hidden -FilePath "powershell.exe" -ArgumentList "-NoProfile","-ExecutionPolicy","Bypass","-File",$winNotifyScript,"-Msg",("`"$trainerMsg`""),"-Title",("'Peon Trainer'"),"-Color","blue","-Style",$notifStyle }
    }
}
exit 0
