#Requires -Version 5.1
<#
.SYNOPSIS
  OpenClaw (小龙虾) Windows one-click installer wrapper.

.DESCRIPTION
  Downloads and runs the official https://openclaw.ai/install.ps1, then runs a
  unified onboard path (openclaw onboard --install-daemon) unless skipped.
  Canonical copy: scripts/install-openclaw.ps1
  Double-click entry: 一键安装-OpenClaw.bat
#>
[CmdletBinding()]
param(
    [switch]$SkipOnboard,
    [switch]$DryRun,
    [switch]$NoVerify,
    [ValidateSet('npm', 'git')]
    [string]$InstallMethod = 'npm',
    [string]$Tag = 'latest',
    [string]$GitDir = ''
)

$ErrorActionPreference = 'Stop'
$AppName = 'OpenClaw (小龙虾)'
$InstallUrl = 'https://openclaw.ai/install.ps1'
$LogDir = Join-Path $env:LOCALAPPDATA 'OpenClawInstaller\logs'
$LogFile = Join-Path $LogDir ("install-{0:yyyyMMdd-HHmmss}.log" -f (Get-Date))

function Write-Log {
    param([string]$Message, [string]$Level = 'INFO')
    $line = "[{0}] [{1}] {2}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Level, $Message
    Write-Host $Message
    try { Add-Content -LiteralPath $LogFile -Value $line -Encoding UTF8 } catch { }
}

function Die {
    param([string]$Message)
    Write-Log "ERROR: $Message" 'ERROR'
    Write-Host "Log: $LogFile" -ForegroundColor Red
    exit 1
}

function Test-IsWindows {
    if ($PSVersionTable.PSEdition -eq 'Core') {
        return ($IsWindows -eq $true)
    }
    return $true
}

function Ensure-LogDir {
    if (-not (Test-Path -LiteralPath $LogDir)) {
        New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
    }
}

function Ensure-ProcessBypass {
    try {
        Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force -ErrorAction Stop
        Write-Log "ExecutionPolicy (Process) set to Bypass"
    } catch {
        Write-Log "Could not set ExecutionPolicy: $($_.Exception.Message)" 'WARN'
    }
}

function Refresh-Path {
    $machine = [Environment]::GetEnvironmentVariable('Path', 'Machine')
    $user = [Environment]::GetEnvironmentVariable('Path', 'User')
    $parts = @()
    if ($machine) { $parts += $machine }
    if ($user) { $parts += $user }
    if ($env:Path) { $parts += $env:Path }

    $npmApps = Join-Path $env:APPDATA 'npm'
    if (Test-Path -LiteralPath $npmApps) { $parts = @($npmApps) + $parts }

    $localOpenClaw = Join-Path $env:USERPROFILE '.openclaw\bin'
    if (Test-Path -LiteralPath $localOpenClaw) { $parts = @($localOpenClaw) + $parts }

    $localBin = Join-Path $env:USERPROFILE '.local\bin'
    if (Test-Path -LiteralPath $localBin) { $parts = @($localBin) + $parts }

    try {
        $npmCmd = Get-Command npm.cmd -ErrorAction SilentlyContinue
        if ($npmCmd) {
            $prefix = & npm.cmd config get prefix 2>$null
            if ($LASTEXITCODE -eq 0 -and $prefix) {
                $prefix = $prefix.Trim()
                if ($prefix) { $parts = @($prefix, (Join-Path $prefix 'bin')) + $parts }
            }
        }
    } catch { }

    $env:Path = ($parts -join ';')
}

function Resolve-OpenClaw {
    Refresh-Path
    $cmd = Get-Command openclaw.cmd -ErrorAction SilentlyContinue
    if (-not $cmd) { $cmd = Get-Command openclaw -ErrorAction SilentlyContinue }
    if ($cmd) { return $cmd.Source }
    $candidates = @(
        (Join-Path $env:APPDATA 'npm\openclaw.cmd'),
        (Join-Path $env:USERPROFILE '.openclaw\bin\openclaw.cmd'),
        (Join-Path $env:USERPROFILE '.local\bin\openclaw.cmd')
    )
    foreach ($c in $candidates) {
        if (Test-Path -LiteralPath $c) { return $c }
    }
    return $null
}

function Test-Network {
    Write-Log 'Checking network...'
    try {
        $resp = Invoke-WebRequest -Uri $InstallUrl -UseBasicParsing -Method Head -TimeoutSec 15
        if ($resp.StatusCode -ge 400) {
            # Some hosts reject HEAD; try a tiny GET range via full GET fallback
            $null = Invoke-WebRequest -Uri $InstallUrl -UseBasicParsing -TimeoutSec 30
        }
        Write-Log '  OK'
    } catch {
        try {
            $null = Invoke-WebRequest -Uri $InstallUrl -UseBasicParsing -TimeoutSec 30
            Write-Log '  OK'
        } catch {
            Die "Cannot reach $InstallUrl. Check network / proxy / firewall. $($_.Exception.Message)"
        }
    }
}

function Invoke-OfficialInstaller {
    Write-Log "Downloading official installer: $InstallUrl"
    if ($DryRun) {
        Write-Log "[dry-run] would download and run install.ps1 (Method=$InstallMethod Tag=$Tag SkipOnboard=$SkipOnboard)"
        return
    }

    $tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("openclaw-install-{0}.ps1" -f [guid]::NewGuid().ToString('N'))
    try {
        Invoke-WebRequest -Uri $InstallUrl -UseBasicParsing -OutFile $tmp -TimeoutSec 120
        Write-Log "Running official installer..."
        Write-Log "  Method: $InstallMethod  Tag: $Tag  Onboard: deferred to wrapper"

        # Always skip official onboard; we unify onboard with --install-daemon later.
        $argList = @(
            '-NoProfile'
            '-ExecutionPolicy', 'Bypass'
            '-File', $tmp
            '-NoOnboard'
            '-InstallMethod', $InstallMethod
            '-Tag', $Tag
        )
        if ($GitDir) {
            $argList += @('-GitDir', $GitDir)
        }
        if ($DryRun) {
            $argList += '-DryRun'
        }

        $p = Start-Process -FilePath 'powershell.exe' -ArgumentList $argList -Wait -PassThru -NoNewWindow
        if ($p.ExitCode -ne 0) {
            Die "Official installer exited with code $($p.ExitCode). See log: $LogFile"
        }
        Write-Log 'Official installer finished.'
    } finally {
        Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
    }
}

function Invoke-OnboardIfNeeded {
    if ($SkipOnboard -or $DryRun) { return }

    $bin = Resolve-OpenClaw
    if (-not $bin) {
        Write-Log "openclaw not found on PATH after install." 'WARN'
        Write-Log '  Open a NEW PowerShell window and run: openclaw onboard --install-daemon' 'WARN'
        Write-Log '  Or: $env:Path = "$env:APPDATA\npm;$env:Path"' 'WARN'
        return
    }

    $configPath = Join-Path $env:USERPROFILE '.openclaw\openclaw.json'
    $hasConfig = Test-Path -LiteralPath $configPath
    $gatewayOk = $false
    if ($hasConfig) {
        try {
            & $bin gateway status 2>$null | Out-Null
            if ($LASTEXITCODE -eq 0) { $gatewayOk = $true }
        } catch { }
    }

    if ($hasConfig -and $gatewayOk) {
        Write-Log 'Config and gateway look ready — skipping onboard.'
        return
    }

    if ($hasConfig) {
        Write-Log 'Config found but gateway not ready. Running: openclaw onboard --install-daemon'
    } else {
        Write-Log 'Starting onboarding wizard (API key / gateway / daemon)...'
        Write-Log "  Command: $bin onboard --install-daemon"
    }

    try {
        & $bin onboard --install-daemon
    } catch {
        Write-Log "Onboarding did not finish: $($_.Exception.Message)" 'WARN'
        Write-Log 'Rerun later: openclaw onboard --install-daemon' 'WARN'
    }
}

function Invoke-Verify {
    if ($NoVerify -or $DryRun) { return }
    Write-Log 'Verifying installation...'
    $bin = Resolve-OpenClaw
    if (-not $bin) {
        Write-Log "'openclaw' not found on PATH." 'WARN'
        Write-Log '  Try a NEW PowerShell window, or:' 'WARN'
        Write-Log '  $env:Path = "$env:APPDATA\npm;$env:Path"' 'WARN'
        return
    }
    Write-Log "  openclaw: $bin"
    try { & $bin --version } catch { Write-Log $_.Exception.Message 'WARN' }
    try { & $bin doctor --non-interactive 2>$null } catch {
        try { & $bin doctor } catch { }
    }
    try { & $bin gateway status 2>$null } catch { }
    Write-Log "  Log saved to: $LogFile"
}

function Show-Banner {
    Write-Host ''
    Write-Host '=============================================='
    Write-Host "  $AppName Windows Installer"
    Write-Host '=============================================='
    Write-Host ''
}

function Show-NextSteps {
    Write-Host ''
    Write-Host '=============================================='
    Write-Host '  Installation finished'
    Write-Host '=============================================='
    Write-Host ''
    Write-Host 'Next steps (open a NEW PowerShell if needed):'
    Write-Host '  1. $env:Path = "$env:APPDATA\npm;$env:Path"'
    Write-Host '  2. openclaw dashboard'
    Write-Host '  3. openclaw gateway status'
    Write-Host ''
    Write-Host 'User guide (Chinese): OpenClaw用户手册.txt'
    Write-Host "Log: $LogFile"
    Write-Host 'Docs: https://docs.openclaw.ai/start/getting-started'
    Write-Host ''
}

# --- main ---
Ensure-LogDir
try { Start-Transcript -Path $LogFile -Append -Force | Out-Null } catch { }

Show-Banner

if (-not (Test-IsWindows)) {
    Die 'This installer only supports Windows.'
}

Write-Log ("User: {0}" -f $env:USERNAME)
Write-Log ("PowerShell: {0}" -f $PSVersionTable.PSVersion)
Ensure-ProcessBypass
Test-Network
Invoke-OfficialInstaller
Refresh-Path
Invoke-OnboardIfNeeded
Invoke-Verify
Show-NextSteps
try { Stop-Transcript | Out-Null } catch { }
exit 0
