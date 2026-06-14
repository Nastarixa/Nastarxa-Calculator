param(
    [Parameter(Mandatory = $true)]
    [string]$InputTextPath,

    [Parameter(Mandatory = $true)]
    [string]$OutputPngPath
)

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing

$lines = Get-Content -LiteralPath $InputTextPath
$fileLine = ($lines | Where-Object { $_ -like "File:*" } | Select-Object -First 1)
$workLine = ($lines | Where-Object { $_ -like "Work Time:*" } | Select-Object -First 1)
$totalLapsLine = ($lines | Where-Object { $_ -like "Total Laps:*" } | Select-Object -First 1)
$fastestLine = ($lines | Where-Object { $_ -like "Fastest:*" } | Select-Object -First 1)
$slowestLine = ($lines | Where-Object { $_ -like "Slowest:*" } | Select-Object -First 1)
$averageLine = ($lines | Where-Object { $_ -like "Average:*" } | Select-Object -First 1)
$dayLine = ($lines | Where-Object { $_ -like "Day:*" } | Select-Object -First 1)
$saveLine = ($lines | Where-Object { $_ -like "Save Time:*" } | Select-Object -First 1)
$dateLine = ($lines | Where-Object { $_ -like "Date:*" } | Select-Object -First 1)

$lapLines = New-Object System.Collections.Generic.List[string]
$inLaps = $false
foreach ($line in $lines) {
    if ($line -match '^Laps:') {
        $inLaps = $true
        continue
    }
    if ($inLaps -and $line -match '^-+') {
        break
    }
    if ($inLaps -and $line.Trim()) {
        $lapLines.Add($line.Trim())
    }
}

$width = 920
$height = [Math]::Max(760, 340 + ($lapLines.Count * 32) + 130)
$bmp = New-Object System.Drawing.Bitmap $width, $height
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.Clear([System.Drawing.Color]::White)
$g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::ClearTypeGridFit

$fontSmall = New-Object System.Drawing.Font "Georgia", 13
$fontLabel = New-Object System.Drawing.Font "Segoe UI", 14, ([System.Drawing.FontStyle]::Bold)
$fontBig = New-Object System.Drawing.Font "Consolas", 36, ([System.Drawing.FontStyle]::Bold)
$fontLap = New-Object System.Drawing.Font "Georgia", 18
$fontTime = New-Object System.Drawing.Font "Consolas", 18
$fontDiff = New-Object System.Drawing.Font "Consolas", 16
$brushText = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(17, 24, 39))
$brushMuted = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(71, 85, 105))
$brushBlue = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(21, 101, 192))
$brushGreen = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(22, 122, 54))
$penLine = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(220, 226, 235)), 2

try {
    $x = 38
    $right = $width - 38
    $y = 28

    $g.DrawString($fileLine, $fontSmall, $brushMuted, $x, $y)
    $y += 36
    $g.DrawLine($penLine, $x, $y, $right, $y)
    $y += 20

    $g.DrawString("WORK TIME", $fontLabel, $brushBlue, $x, $y)
    $y += 30
    $work = ($workLine -replace '^Work Time:\s*', '')
    $g.DrawString($work, $fontBig, $brushText, $x + 6, $y)
    $y += 72

    $g.DrawString($totalLapsLine, $fontSmall, $brushText, $x + 4, $y)
    $g.DrawString($averageLine, $fontSmall, $brushText, 420, $y)
    $y += 28
    $g.DrawString($fastestLine, $fontSmall, $brushGreen, $x + 4, $y)
    $y += 26
    $g.DrawString($slowestLine, $fontSmall, $brushMuted, $x + 4, $y)
    $y += 38

    $g.DrawLine($penLine, $x, $y, $right, $y)
    $y += 18
    $g.DrawString("LAPS", $fontLabel, $brushBlue, $x, $y)
    $y += 32

    foreach ($lap in $lapLines) {
        if ($lap -match '^(.*?)\s+(\d{2}:\d{2}:\d{2})\s+d\s+([+-]\d{2}:\d{2}:\d{2}|--)$') {
            $name = $matches[1].Trim()
            $time = $matches[2]
            $diff = $matches[3]
        } elseif ($lap -match '^(.*?)\s+(\d{2}:\d{2}:\d{2})$') {
            $name = $matches[1].Trim()
            $time = $matches[2]
            $diff = ""
        } else {
            $name = $lap
            $time = ""
            $diff = ""
        }
        $g.DrawString($name, $fontLap, $brushText, $x, $y)
        $g.DrawString($time, $fontTime, $brushMuted, 420, $y)
        if ($diff) {
            $g.DrawString("d $diff", $fontDiff, $brushGreen, 650, $y + 2)
        }
        $y += 32
    }

    $y += 10
    $g.DrawLine($penLine, $x, $y, $right, $y)
    $y += 20
    $g.DrawString($dayLine, $fontSmall, $brushText, $x, $y)
    $y += 26
    $g.DrawString($saveLine, $fontSmall, $brushText, $x, $y)
    $y += 26
    $g.DrawString($dateLine, $fontSmall, $brushText, $x, $y)

    $dir = Split-Path -Parent $OutputPngPath
    if ($dir -and -not (Test-Path -LiteralPath $dir)) {
        New-Item -ItemType Directory -Force -Path $dir | Out-Null
    }
    $bmp.Save($OutputPngPath, [System.Drawing.Imaging.ImageFormat]::Png)
} finally {
    $g.Dispose()
    $bmp.Dispose()
    $fontSmall.Dispose()
    $fontLabel.Dispose()
    $fontBig.Dispose()
    $fontLap.Dispose()
    $fontTime.Dispose()
    $fontDiff.Dispose()
    $brushText.Dispose()
    $brushMuted.Dispose()
    $brushBlue.Dispose()
    $brushGreen.Dispose()
    $penLine.Dispose()
}
