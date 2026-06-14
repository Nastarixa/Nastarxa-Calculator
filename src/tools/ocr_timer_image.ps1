param(
    [Parameter(Mandatory = $true)]
    [string]$ImagePath
)

$ErrorActionPreference = "Stop"

Add-Type -AssemblyName System.Runtime.WindowsRuntime

$null = [Windows.Storage.StorageFile, Windows.Storage, ContentType = WindowsRuntime]
$null = [Windows.Graphics.Imaging.BitmapDecoder, Windows.Graphics.Imaging, ContentType = WindowsRuntime]
$null = [Windows.Media.Ocr.OcrEngine, Windows.Foundation, ContentType = WindowsRuntime]

function Await-WinRt($AsyncOperation, $ResultType) {
    $asTask = ([System.WindowsRuntimeSystemExtensions].GetMethods() |
        Where-Object {
            $_.Name -eq "AsTask" -and
            $_.GetParameters().Count -eq 1 -and
            $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1'
        })[0]

    $task = $asTask.MakeGenericMethod($ResultType).Invoke($null, @($AsyncOperation))
    $task.Wait()
    return $task.Result
}

function Read-WindowsOcr($Path) {
    $file = Await-WinRt ([Windows.Storage.StorageFile]::GetFileFromPathAsync($Path)) ([Windows.Storage.StorageFile])
    $stream = Await-WinRt ($file.OpenReadAsync()) ([Windows.Storage.Streams.IRandomAccessStreamWithContentType])
    $decoder = Await-WinRt ([Windows.Graphics.Imaging.BitmapDecoder]::CreateAsync($stream)) ([Windows.Graphics.Imaging.BitmapDecoder])
    $bitmap = Await-WinRt ($decoder.GetSoftwareBitmapAsync()) ([Windows.Graphics.Imaging.SoftwareBitmap])
    $engine = [Windows.Media.Ocr.OcrEngine]::TryCreateFromUserProfileLanguages()

    if ($null -eq $engine) {
        throw "Windows OCR is not available for the current user profile language."
    }

    $result = Await-WinRt ($engine.RecognizeAsync($bitmap)) ([Windows.Media.Ocr.OcrResult])
    $lines = New-Object System.Collections.Generic.List[string]
    foreach ($line in $result.Lines) {
        $lines.Add($line.Text)
    }
    return ($lines -join "`r`n")
}

function Find-Tesseract {
    $cmd = Get-Command tesseract.exe -ErrorAction SilentlyContinue
    if ($cmd) {
        return $cmd.Source
    }

    $candidates = @(
        (Join-Path $env:ProgramFiles "Tesseract-OCR\tesseract.exe"),
        (Join-Path ${env:ProgramFiles(x86)} "Tesseract-OCR\tesseract.exe"),
        (Join-Path $env:LOCALAPPDATA "Programs\Tesseract-OCR\tesseract.exe")
    )

    foreach ($candidate in $candidates) {
        if ($candidate -and (Test-Path -LiteralPath $candidate)) {
            return $candidate
        }
    }

    return $null
}

function Read-TesseractOcr($Path) {
    $tesseract = Find-Tesseract
    if (-not $tesseract) {
        return ""
    }

    $outBase = Join-Path $env:TEMP ("nastarxa_timer_tess_" + [guid]::NewGuid().ToString("N"))
    try {
        $args = @($Path, $outBase, "--psm", "6")
        $p = Start-Process -FilePath $tesseract -ArgumentList $args -NoNewWindow -Wait -PassThru
        $outFile = $outBase + ".txt"
        if ($p.ExitCode -eq 0 -and (Test-Path -LiteralPath $outFile)) {
            return Get-Content -LiteralPath $outFile -Raw
        }
        return ""
    } finally {
        Remove-Item -LiteralPath ($outBase + ".txt") -ErrorAction SilentlyContinue
    }
}

$texts = New-Object System.Collections.Generic.List[string]
$tesseractText = Read-TesseractOcr $ImagePath
if ($tesseractText) {
    $texts.Add($tesseractText)
}

$texts.Add((Read-WindowsOcr $ImagePath))

($texts -join "`r`n")
