$ScriptVersion = '1.0.0'
# File: AutoRestart.ps1
function Start-ProcessLoop {
    param(
        [string]  $JavaExecutable,
        [string[]]$JavaArgs,
        [string]  $ProjectRoot,
        [int]     $RestartSleep = 120,
        [bool]    $EnableLogging = $true,
        [bool]    $EnableConsoleOut = $true
    )
    while ($true) {
        if ($EnableLogging) {
            $res = Start-ServerWithLogging -JavaExecutable $JavaExecutable -JavaArgs $JavaArgs -ProjectRoot $ProjectRoot
        } else {
            if ($EnableConsoleOut) { Write-Host 'Starting without logging...' -ForegroundColor Yellow }
            $pr = Start-Process -FilePath $JavaExecutable -ArgumentList $JavaArgs -NoNewWindow -PassThru
            $pr.WaitForExit()
            $res = @{ ExitCode = $pr.ExitCode }
        }
        Write-Host "[INFO] Crash code $($res.ExitCode)" -ForegroundColor Red
        Write-Host "[INFO] Restarting in $RestartSleep seconds..." -ForegroundColor Cyan
        Start-Sleep -Seconds $RestartSleep
    }
}