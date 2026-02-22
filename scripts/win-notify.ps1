param(
    [string]$Msg,
    [string]$Title,
    [string]$Color = "red",
    [string]$Style = "standard",
    [string]$IconPath
)

# Function to escape XML for Toast
function Escape-Xml {
    param([string]$str)
    if (-not $str) { return "" }
    $str = $str -replace '&', '&amp;' -replace '<', '&lt;' -replace '>', '&gt;' -replace '"', '&quot;' -replace "'", '&apos;'
    return $str
}

if ($Style -eq "standard") {
    # Toast notification (Native Windows Center)
    $tmpFile = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), "peon-toast-$([Guid]::NewGuid()).xml")
    $iconXml = ""
    if ($IconPath -and (Test-Path $IconPath)) {
        $fullIconPath = [System.IO.Path]::GetFullPath($IconPath)
        $iconXml = "<image placement=`"appLogoOverride`" hint-crop=`"circle`" src=`"$fullIconPath`" />"
    }

    $safeTitle = Escape-Xml $Title
    $safeMsg = Escape-Xml $Msg

    $xml = @"
<toast duration="short">
  <visual>
    <binding template="ToastGeneric">
      <text>$safeMsg</text>
      <text>$safeTitle</text>
      $iconXml
    </binding>
  </visual>
</toast>
"@
    Set-Content -Path $tmpFile -Value $xml -Encoding UTF8

    try {
        [Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] | Out-Null
        [Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom, ContentType = WindowsRuntime] | Out-Null

        $APP_ID = "{1AC14E77-02E7-4E5D-B744-2EB1AE5198B7}\WindowsPowerShell\v1.0\powershell.exe"
        $toastXml = New-Object Windows.Data.Xml.Dom.XmlDocument
        $toastXml.LoadXml((Get-Content $tmpFile -Raw -Encoding UTF8))
        $toast = New-Object Windows.UI.Notifications.ToastNotification $toastXml
        $toast.Tag = "peon-ping"
        $toast.Group = "peon-ping"

        [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier($APP_ID).Show($toast)
    } catch {
        $Style = "overlay" # Fallback
    } finally {
        Remove-Item $tmpFile -ErrorAction SilentlyContinue
    }
}

if ($Style -eq "overlay") {
    # Overlay popup (Legacy Forms)
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing

    $rgb_r = 180; $rgb_g = 0; $rgb_b = 0
    switch ($Color) {
        "blue"   { $rgb_r = 30;  $rgb_g = 80;  $rgb_b = 180 }
        "yellow" { $rgb_r = 200; $rgb_g = 160; $rgb_b = 0   }
        "red"    { $rgb_r = 180; $rgb_g = 0;   $rgb_b = 0   }
    }

    $slotDir = Join-Path ([System.IO.Path]::GetTempPath()) "peon-ping-popups"
    if (-not (Test-Path $slotDir)) { New-Item -ItemType Directory -Path $slotDir | Out-Null }

    $slot = 0
    while ($slot -lt 5) {
        $path = Join-Path $slotDir "slot-$slot"
        try {
            New-Item -ItemType Directory -Path $path -ErrorAction Stop | Out-Null
            break
        } catch {
            $slot++
        }
    }

    if ($slot -ge 5) {
        Get-ChildItem -Path $slotDir -Directory | Where-Object { $_.LastWriteTime -lt (Get-Date).AddMinutes(-1) } | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
        $slot = 0
        $path = Join-Path $slotDir "slot-0"
        if (-not (Test-Path $path)) { New-Item -ItemType Directory -Path $path | Out-Null }
    }

    $y_offset = 40 + $slot * 90

    try {
        $forms = @()
        foreach ($screen in [System.Windows.Forms.Screen]::AllScreens) {
            $form = New-Object System.Windows.Forms.Form
            $form.FormBorderStyle = 'None'
            $form.BackColor = [System.Drawing.Color]::FromArgb($rgb_r, $rgb_g, $rgb_b)
            $form.Size = New-Object System.Drawing.Size(500, 80)
            $form.TopMost = $true
            $form.ShowInTaskbar = $false
            $form.StartPosition = 'Manual'
            $form.Location = New-Object System.Drawing.Point(
                ($screen.WorkingArea.X + ($screen.WorkingArea.Width - 500) / 2),
                ($screen.WorkingArea.Y + $y_offset)
            )

            $iconSize = 60
            $iconLeft = 10
            if ($IconPath -and (Test-Path $IconPath)) {
                try {
                    $pb = New-Object System.Windows.Forms.PictureBox
                    $img = [System.Drawing.Image]::FromFile($IconPath)
                    $pb.Image = $img
                    $pb.SizeMode = 'Zoom'
                    $pb.Size = New-Object System.Drawing.Size($iconSize, $iconSize)
                    $pb.Location = New-Object System.Drawing.Point($iconLeft, 10)
                    $pb.BackColor = [System.Drawing.Color]::Transparent
                    $form.Controls.Add($pb)

                    $label = New-Object System.Windows.Forms.Label
                    $label.Location = New-Object System.Drawing.Point(($iconLeft + $iconSize + 5), 0)
                    $label.Size = New-Object System.Drawing.Size((500 - $iconLeft - $iconSize - 15), 80)
                } catch {
                    $label = New-Object System.Windows.Forms.Label
                    $label.Dock = 'Fill'
                }
            } else {
                $label = New-Object System.Windows.Forms.Label
                $label.Dock = 'Fill'
            }

            $label.Text = $Msg
            $label.ForeColor = [System.Drawing.Color]::White
            $label.Font = New-Object System.Drawing.Font('Segoe UI', 16, [System.Drawing.FontStyle]::Bold)
            $label.TextAlign = 'MiddleCenter'
            $form.Controls.Add($label)

            $form.Show()
            $forms += $form
        }

        Start-Sleep -Seconds 4
        foreach ($form in $forms) { $form.Close(); $form.Dispose() }
    } finally {
        Remove-Item (Join-Path $slotDir "slot-$slot") -Recurse -Force -ErrorAction SilentlyContinue
    }
}
