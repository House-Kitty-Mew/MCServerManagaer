$ScriptVersion = '1.0.0'
function Start-ProcessLoop {
    param(
        [string] $JavaExecutable,
        [array]  $JavaArgs,
        [string] $ProjectRoot,
        [string] $WorldPath,
        [bool]   $EnableLogging,
        [bool]   $EnableConsoleOut,
        [int]    $RestartSleep
    )

    # CTRL+C handler (omitted for brevity)...

    while ($true) {
        # Cleanup stale session.lock
        $cleanupScript = Join-Path $ProjectRoot 'custom_starter_scripts\Cleanup-SessionLock.ps1'
        if (Test-Path $cleanupScript) {
            . $cleanupScript
            Remove-StaleSessionLock
        }

        # Start the server (logging vs console)
        if ($EnableLogging) {
            # …logging logic…
        } elseif ($EnableConsoleOut) {
            & "$JavaExecutable" @JavaArgs
            $exitCode = $LASTEXITCODE
        } else {
            & "$JavaExecutable" @JavaArgs | Out-Null
            $exitCode = $LASTEXITCODE
        }

        if ($exitCode -eq 0) { break }
        Start-Sleep -Seconds $RestartSleep
    }
}
