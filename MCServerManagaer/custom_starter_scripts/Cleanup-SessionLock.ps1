$ScriptVersion = '1.0.0'
function Remove-StaleSessionLock {
    # Use the globals $ProjectRoot and $worldPath from Setup-Environment.ps1
    $lockFile = Join-Path $ProjectRoot "$worldPath\session.lock"
    # Only attempt deletion if the path is non-null and exists
    if ($null -ne $lockFile -and (Test-Path -Path $lockFile)) {
        Remove-Item -Path $lockFile -Force
    }
}