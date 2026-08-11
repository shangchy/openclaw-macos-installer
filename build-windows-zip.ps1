#Requires -Version 5.1
<#
.SYNOPSIS
  Pack the Windows one-click installer into dist\ as a ZIP.
.EXAMPLE
  powershell -NoProfile -ExecutionPolicy Bypass -File .\build-windows-zip.ps1
#>
[CmdletBinding()]
param(
    [string]$Version = $(if ($env:OPENCLAW_INSTALLER_VERSION) { $env:OPENCLAW_INSTALLER_VERSION } else { '1.0.0' })
)

$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$Stage = Join-Path $Root 'dist\windows-stage'
$OutName = "OpenClaw-Installer-Windows-$Version"
$StageRoot = Join-Path $Stage $OutName
$ZipPath = Join-Path $Root "dist\$OutName.zip"

function Resolve-One {
    param([string]$Directory, [string]$Filter, [string]$Label)
    $hit = Get-ChildItem -LiteralPath $Directory -File -Filter $Filter -ErrorAction SilentlyContinue |
        Select-Object -First 1
    if (-not $hit) { throw "Missing required file ($Label): $Filter under $Directory" }
    return $hit
}

$srcScript = Join-Path $Root 'scripts\install-openclaw.ps1'
if (-not (Test-Path -LiteralPath $srcScript)) {
    throw "Missing required file: $srcScript"
}

# Avoid hardcoding non-ASCII path literals (PowerShell 5.1 file encoding).
$batFile = Resolve-One -Directory $Root -Filter '*-OpenClaw.bat' -Label 'Windows bat launcher'
$winReadme = Resolve-One -Directory $Root -Filter '*-Windows.txt' -Label 'Windows readme'
$userGuide = Get-ChildItem -LiteralPath $Root -File -Filter 'OpenClaw*.txt' -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -notmatch 'Windows' -and $_.Name -notmatch 'README' } |
    Select-Object -First 1

# Detect Feishu guide by content (avoid locale/encoding issues with CJK filenames in PS 5.1)
$feishuGuide = $null
Get-ChildItem -LiteralPath $Root -File -Filter '*.txt' -ErrorAction SilentlyContinue | ForEach-Object {
    if ($feishuGuide) { return }
    try {
        $head = Get-Content -LiteralPath $_.FullName -TotalCount 3 -Encoding UTF8 -ErrorAction Stop
        $text = ($head -join "`n")
        if ($text -match 'Feishu|Lark|飞书') {
            if ($_.Name -notmatch 'OpenClaw' -and $_.Name -notmatch 'Windows' -and $_.Name -notmatch 'README') {
                $script:feishuGuide = $_
            }
        }
    } catch { }
}

Write-Host "→ Staging Windows installer: $StageRoot"
if (Test-Path -LiteralPath $Stage) { Remove-Item -LiteralPath $Stage -Recurse -Force }
New-Item -ItemType Directory -Path (Join-Path $StageRoot 'scripts') -Force | Out-Null

Copy-Item -LiteralPath $srcScript -Destination (Join-Path $StageRoot 'scripts\install-openclaw.ps1') -Force
Copy-Item -LiteralPath $batFile.FullName -Destination (Join-Path $StageRoot $batFile.Name) -Force
Copy-Item -LiteralPath $winReadme.FullName -Destination (Join-Path $StageRoot $winReadme.Name) -Force
if ($userGuide) {
    Copy-Item -LiteralPath $userGuide.FullName -Destination (Join-Path $StageRoot $userGuide.Name) -Force
}
if ($feishuGuide) {
    Copy-Item -LiteralPath $feishuGuide.FullName -Destination (Join-Path $StageRoot $feishuGuide.Name) -Force
    Copy-Item -LiteralPath $feishuGuide.FullName -Destination (Join-Path $StageRoot 'Feishu-Setup.txt') -Force
}

# ASCII-friendly copy so users who cannot read CJK filenames still find the entry.
Copy-Item -LiteralPath $batFile.FullName -Destination (Join-Path $StageRoot 'Install-OpenClaw.bat') -Force
Copy-Item -LiteralPath $winReadme.FullName -Destination (Join-Path $StageRoot 'README-Windows.txt') -Force

New-Item -ItemType Directory -Path (Join-Path $Root 'dist') -Force | Out-Null
if (Test-Path -LiteralPath $ZipPath) { Remove-Item -LiteralPath $ZipPath -Force }

Write-Host "→ Creating $ZipPath"
Compress-Archive -Path $StageRoot -DestinationPath $ZipPath -Force
Remove-Item -LiteralPath $Stage -Recurse -Force

Write-Host ''
Write-Host 'Done.'
Write-Host "  ZIP: $ZipPath"
Write-Host "  Bat: $($batFile.Name) (+ Install-OpenClaw.bat)"
Write-Host ''
