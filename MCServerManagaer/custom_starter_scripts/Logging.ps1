$ScriptVersion = '1.0.0'
# File: Logging.ps1
function Initialize-Logging {
    param([string]$ProjectRoot)
    $dir = Join-Path $ProjectRoot 'logs\start-server-script-logs'
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    return $dir
}
function Start-ServerWithLogging {
    param(
        [string]  $JavaExecutable,
        [string[]]$JavaArgs,
        [string]  $ProjectRoot
    )
    $dir = Initialize-Logging -ProjectRoot $ProjectRoot
    $ts  = Get-Date -Format 'yyyy-MM-dd_HH-mm-ss'
    $out  = Join-Path $dir "start-$ts.out.log"
    $err  = Join-Path $dir "start-$ts.err.log"
    Write-Host "Launching Java: $JavaExecutable $($JavaArgs -join ' ')" -ForegroundColor Green
    $p = Start-Process -FilePath $JavaExecutable -ArgumentList $JavaArgs `
        -RedirectStandardOutput $out `
        -RedirectStandardError  $err `
        -NoNewWindow -Wait -PassThru
    Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] Server exited code $($p.ExitCode) (out:$out, err:$err)" -ForegroundColor Cyan
    return @{ ExitCode=$p.ExitCode;LogFile=$out }
}
