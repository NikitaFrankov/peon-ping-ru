param(
    [string]$Dir,
    [string]$PacksCsv,
    [switch]$All,
    [switch]$ListRegistry
)

$ProgressPreference = 'SilentlyContinue'
$RegistryUrl = "https://raw.githubusercontent.com/NikitaFrankov/peon-ping-ru/main/registry/index.json"

# --- Constants ---
$ESC = [char]27
$RESET = "$ESC[0m"
$BLUE_BG = "$ESC[44m"
$GRAY_TEXT = "$ESC[90m"
$GREEN_TEXT = "$ESC[92m"
$RED_TEXT = "$ESC[91m"

# --- Helper: Winget-style Progress ---
function Show-WingetProgress($current, $total, $label) {
    $width = 30
    $percent = [math]::Min(100, [math]::Max(0, [math]::Floor(($current / $total) * 100)))
    $filled = [math]::Floor(($percent / 100) * $width)
    $unfilled = $width - $filled
    $bar = "$BLUE_BG" + (" " * $filled) + "$RESET" + ("-" * $unfilled)
    $winWidth = 80
    try { $winWidth = [console]::WindowWidth } catch {}
    $status = "`r  $bar $percent% $GRAY_TEXT$($label)$RESET"
    if ($status.Length -lt $winWidth) { $status = $status.PadRight($winWidth + 10) }
    else { $status = $status.Substring(0, $winWidth - 1) }
    [console]::Write($status)
}

# --- SHA256 Function (Shared for Main thread) ---
function Get-FileSha256($path) {
    if (-not (Test-Path $path)) { return "" }
    try {
        $stream = [System.IO.File]::OpenRead($path)
        $sha = [System.Security.Cryptography.SHA256]::Create()
        $hash = $sha.ComputeHash($stream)
        $stream.Close()
        return ([System.BitConverter]::ToString($hash).Replace("-", "")).ToLower()
    } catch { if ($null -ne $stream) { $stream.Close() }; return "" }
}

# --- Background Download ScriptBlock ---
$DownloadJob = {
    param($sfile, $target, $url, $storedHash)
    
    # Internal SHA256 helper for the thread
    function Get-Sha256($p) {
        if (-not (Test-Path $p)) { return "" }
        $s = [System.IO.File]::OpenRead($p)
        $h = ([System.Security.Cryptography.SHA256]::Create()).ComputeHash($s)
        $s.Close()
        return ([System.BitConverter]::ToString($h).Replace("-", "")).ToLower()
    }

    $result = @{ file = $sfile; success = $true; skipped = $false; hash = "" }
    
    try {
        # 1. Check if already valid
        if ($storedHash -and (Test-Path $target)) {
            if ($storedHash -eq (Get-Sha256 $target)) {
                $result.skipped = $true
                $result.hash = $storedHash
                return $result
            }
        }

        # 2. Download
        $wc = New-Object System.Net.WebClient
        $wc.DownloadFile($url, $target)
        
        # 3. Compute new hash
        $result.hash = Get-Sha256 $target
    } catch {
        $result.success = $false
    }
    return $result
}

# --- Execution ---
$WebClient = New-Object System.Net.WebClient
$WebClient.Encoding = [System.Text.Encoding]::UTF8

Write-Host "Подключение к реестру..." -ForegroundColor Cyan
try { $registry = $WebClient.DownloadString($RegistryUrl) | ConvertFrom-Json } 
catch { Write-Host "  Ошибка сети." -ForegroundColor Red; return }

$packsDir = Join-Path $Dir "packs"
$installed = if (Test-Path $packsDir) { Get-ChildItem $packsDir -Directory | Select-Object -ExpandProperty Name } else { @() }

if ($ListRegistry) {
    foreach ($p in $registry.packs) {
        $m = if ($installed -contains $p.name) { "$GREEN_TEXT[установлен]$RESET" } else { "" }
        Write-Host ("  {0,-20} {1} {2}" -f $p.name, $p.display_name, $m)
    }
    exit 0
}

$allPacks = @($registry.packs)
$selected = if ($All) { $allPacks } elseif ($PacksCsv) { $n = $PacksCsv -split ',' | ForEach-Object { $_.Trim() }; $allPacks | Where-Object { $n -contains $_.name } } else { @() }
if (-not $selected) { exit 0 }

# Limit initial download
$limit = 5
$toProcess = if ($All -and $selected.Count -gt $limit) { $selected | Select-Object -First $limit } else { $selected }
$remaining = $selected.Count - $toProcess.Count

Write-Host "Обработка паков: $($toProcess.Count) ($($toProcess.name -join ', '))" -ForegroundColor Cyan

# Prepare Runspace Pool
$Pool = [RunspaceFactory]::CreateRunspacePool(1, 8)
$Pool.Open()

foreach ($pack in $toProcess) {
    $pDir = Join-Path $packsDir $pack.name
    $sDir = Join-Path $pDir "sounds"
    if (-not (Test-Path $sDir)) { New-Item -ItemType Directory -Path $sDir -Force | Out-Null }
    
    $pBase = "https://raw.githubusercontent.com/$($pack.source_repo)/$($pack.source_ref)/$($pack.source_path)"
    $checkFile = Join-Path $pDir ".checksums"
    if (-not (Test-Path $checkFile)) { Set-Content $checkFile "" }
    $checksums = @{}
    Get-Content $checkFile | ForEach-Object { if ($_ -match "(.+) (.+)") { $checksums[$matches[1]] = $matches[2] } }

    # Manifest & Icon (Serial, they are fast)
    try { $WebClient.DownloadFile("$pBase/openpeon.json", (Join-Path $pDir "openpeon.json")) } catch { continue }
    $manifest = Get-Content (Join-Path $pDir "openpeon.json") -Raw | ConvertFrom-Json
    $icon = if ($manifest.icon) { $manifest.icon } else { "icon.png" }
    try { $WebClient.DownloadFile("$pBase/$icon", (Join-Path $pDir $icon)) } catch {}

    # Sounds
    $files = @()
    foreach ($pr in $manifest.categories.PSObject.Properties) {
        foreach ($s in $pr.Value.sounds) { $fn = Split-Path $s.file -Leaf; if ($fn -and $files -notcontains $fn) { $files += $fn } }
    }

    Write-Host "Пак: $($pack.name)" -ForegroundColor White
    $tasks = @()
    foreach ($f in $files) {
        $url = "$pBase/sounds/$([uri]::EscapeDataString($f).Replace('%21','!').Replace('%27',`"'`").Replace('%28','(').Replace('%29',')').Replace('%2A','*'))"
        $powershell = [PowerShell]::Create().AddScript($DownloadJob).AddArgument($f).AddArgument((Join-Path $sDir $f)).AddArgument($url).AddArgument($checksums[$f])
        $powershell.RunspacePool = $Pool
        $tasks += @{ ps = $powershell; handle = $powershell.BeginInvoke(); file = $f }
    }

    $completed = 0
    $errors = @()
    while ($completed -lt $tasks.Count) {
        $completed = ($tasks | Where-Object { $_.handle.IsCompleted }).Count
        $lastFile = if ($completed -gt 0) { ($tasks | Where-Object { $_.handle.IsCompleted } | Select-Object -Last 1).file } else { "..." }
        Show-WingetProgress $completed $tasks.Count "Загрузка: $lastFile"
        Start-Sleep -Milliseconds 100
    }

    # Finalize checksums
    $newChecksums = @()
    foreach ($t in $tasks) {
        $res = $t.ps.EndInvoke($t.handle)
        if ($res.success) { $newChecksums += "$($res.file) $($res.hash)" } else { $errors += $res.file }
        $t.ps.Dispose()
    }
    $newChecksums | Set-Content $checkFile -Encoding UTF8
    [console]::WriteLine("")
    if ($errors.Count -eq 0) { Write-Host "  $GREEN_TEXT+ $($pack.name) готов$RESET" }
    else { Write-Host "  $RED_TEXT! $($pack.name): ошибок: $($errors.Count)$RESET" }
}

$Pool.Close()
$Pool.Dispose()

if ($remaining -gt 0) {
    Write-Host "`nОсталось ещё $remaining паков. Используйте: peon packs install <имя>" -ForegroundColor Yellow
}
