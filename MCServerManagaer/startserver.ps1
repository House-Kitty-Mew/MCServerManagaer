$ScriptVersion = '1.0.0'
# File: startserver.ps1
param()

# ── Elevate if not Admin ────────────────────────────────────────────────────
$me = [Security.Principal.WindowsIdentity]::GetCurrent()
$prn = [Security.Principal.WindowsPrincipal]::new($me)
if (-not $prn.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Start-Process pwsh -ArgumentList '-NoProfile','-ExecutionPolicy','Bypass','-File',"$PSCommandPath" -Verb RunAs
    exit
}

# ── 1) Script folder & config ───────────────────────────────────────────────
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$cfgPath   = Join-Path $scriptDir 'config.xml'
if (-not (Test-Path $cfgPath)) { $cfgPath = Read-Host 'config.xml path:' }
Write-Host "Loading config from: $cfgPath" -ForegroundColor Green
[xml]$cfg = Get-Content $cfgPath -Raw

# ── 2) Project root override ────────────────────────────────────────────────
$prOverride = $cfg.Config.ProjectRoot.path.Trim()
if ($prOverride -and (Test-Path $prOverride)) {
    $pr = $prOverride
    Write-Host "Project root overridden to: $pr" -ForegroundColor Cyan
} else {
    $pr = $scriptDir
    Write-Host "Using script folder as project root: $pr" -ForegroundColor Cyan
}

# ── 3) Locate functions manifest ─────────────────────────────────────────────
$fnPath = Join-Path $pr 'functions.xml'
if (-not (Test-Path $fnPath)) { $fnPath = Read-Host 'functions.xml path:' }
Write-Host "Using manifest: $fnPath" -ForegroundColor Green

# ── 4) Update manifest & load helper scripts ─────────────────────────────────
Write-Host 'Updating functions manifest...' -ForegroundColor Green
. (Join-Path $pr 'custom_starter_scripts\Update-FunctionsManifest.ps1') -ProjectRoot $pr

Write-Host 'Loading helper scripts...' -ForegroundColor Green
$helpersDir = Join-Path $pr 'custom_starter_scripts'
[xml]$funcMan = Get-Content $fnPath -Raw
foreach ($e in $funcMan.Functions.Script) {
    $scriptFile = Join-Path $helpersDir $e.file
    if (Test-Path $scriptFile) {
        Write-Host "Sourcing $scriptFile" -ForegroundColor Cyan
        . $scriptFile
    } else {
        Write-Warning "Helper not found: $scriptFile"
    }
}

# ── 5) Resolve Java executable ────────────────────────────────────────────────
$javaCfg = $cfg.Config.JavaExecutable.path.Trim('"')
if (Test-Path $javaCfg) {
    $java = $javaCfg
} else {
    Write-Warning "Java not found at [$javaCfg]"
    $onPath = Get-Command java -ErrorAction SilentlyContinue
    if ($onPath) {
        $java = $onPath.Source
        Write-Host "Found java on PATH: $java" -ForegroundColor Cyan
    } else {
        $prompt = Read-Host 'Enter full path to java.exe'
        if (Test-Path $prompt) { $java = $prompt }
        else { Throw 'Cannot locate a Java executable. Aborting.' }
    }
}
Write-Host "Using Java: $java" -ForegroundColor Green

# ── 6) Read other settings ───────────────────────────────────────────────────
$initialRam          = $cfg.Config.Memory.initialIfOptimized
$maxRam              = $cfg.Config.Memory.maxIfOptimized
$jarName             = $cfg.Config.JarName
$restartSleep        = [int]$cfg.Config.RestartSleepSeconds
$enableLogging       = [bool]$cfg.Config.Logging.enabled
$enableConsoleOutput = [bool]$cfg.Config.ConsoleOutput.enabled

# ── 7) Build Java args ──────────────────────────────────────────────────────
$javaArgs = @(
    "-Xms$initialRam"
    "-Xmx$maxRam"
    "-jar", $jarName
    "nogui"
)

# ── 8) Launch & restart loop ────────────────────────────────────────────────
while ($true) {
    Write-Host "Launching server:" -ForegroundColor Green
    Write-Host "`t$java $($javaArgs -join ' ')" -ForegroundColor Green

    if ($enableLogging) {
        $logDir = Join-Path $pr 'logs\start-server-script-logs'
        if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir | Out-Null }
        $ts = Get-Date -Format 'yyyy-MM-dd_HH-mm-ss'
        $log = Join-Path $logDir "start-$ts.log"

        if ($enableConsoleOutput) {
            & $java $javaArgs 2>&1 | Tee-Object -FilePath $log
        } else {
            & $java $javaArgs *> $log
        }
        $exitCode = $LASTEXITCODE
    }
    else {
        if ($enableConsoleOutput) {
            & $java $javaArgs
        } else {
            & $java $javaArgs *> $null
        }
        $exitCode = $LASTEXITCODE
    }

    Write-Host "Server exited with code $exitCode" -ForegroundColor Yellow
    Write-Host "Restarting in $restartSleep seconds…" -ForegroundColor DarkGray
    Start-Sleep -Seconds $restartSleep
}
