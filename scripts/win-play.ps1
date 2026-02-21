param(
    [Parameter(Mandatory=$true)]
    [string]$path,
    [Parameter(Mandatory = $true)]
    [double]$vol
)

# normalize volume 0..1
if ($vol -lt 0) { $vol = 0 }
if ($vol -gt 1) { $vol = 1 }

# resolve path early
try { $path = (Resolve-Path -LiteralPath $path).Path } catch {}

# Определяем P/Invoke один раз
if (-not ("WinMM.NativeMethods" -as [type])) {
    Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
using System.Text;

namespace WinMM {
  public static class NativeMethods {
    [DllImport("winmm.dll", CharSet = CharSet.Unicode)]
    public static extern int mciSendString(string command, StringBuilder buffer, int bufferSize, IntPtr callback);
  }
}
"@
}

function Invoke-Mci([string]$cmd) {
    $sb = New-Object System.Text.StringBuilder 256
    $rc = [WinMM.NativeMethods]::mciSendString($cmd, $sb, $sb.Capacity, [IntPtr]::Zero)
    if ($rc -ne 0) {
        throw "MCI command failed (rc=$rc): $cmd"
    }
    $sb.ToString()
}

$alias = "peon"

try {
    try { Invoke-Mci "close $alias" | Out-Null } catch {}

    Invoke-Mci "open `"$path`" type mpegvideo alias $alias" | Out-Null

    $mciVol = [int][math]::Round($vol * 1000)
    Invoke-Mci "setaudio $alias volume to $mciVol" | Out-Null

    Invoke-Mci "play $alias" | Out-Null

    $timeoutSeconds = 60
    $sw = [System.Diagnostics.Stopwatch]::StartNew()

    $lengthMs = 0
    try { $lengthMs = [int](Invoke-Mci "status $alias length") } catch { $lengthMs = 0 }

    while ($sw.Elapsed.TotalSeconds -lt $timeoutSeconds) {
        Start-Sleep -Milliseconds 100
        $posMs = 0
        try { $posMs = [int](Invoke-Mci "status $alias position") } catch { $posMs = 0 }
        if ($lengthMs -gt 0 -and $posMs -ge ($lengthMs - 100)) { break }
    }

    Invoke-Mci "stop $alias" | Out-Null
    Invoke-Mci "close $alias" | Out-Null
    exit 0
}
catch {
    try { Invoke-Mci "close $alias" | Out-Null } catch {}
    Write-Error $_
    exit 1
}
