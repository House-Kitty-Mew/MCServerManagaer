$ScriptVersion = '1.0.0'
function Get-JavaArgs {
    param(
        [bool]   $EnableJavaDebug,
        [bool]   $EnableOptimizations,
        [bool]   $UseZGC,
        [string] $InitialRam,
        [string] $MaxRam,
        [string] $JarName
    )

    $debugFlags = @('-Xlog:all=trace')
    $g1Flags    = @(
        '-XX:+UseG1GC',
        '-XX:MaxGCPauseMillis=50',
        '-XX:+ParallelRefProcEnabled',
        '-XX:ConcGCThreads=8',
        '-XX:SurvivorRatio=32',
        '-XX:+DisableExplicitGC'
    )
    $zgcFlags   = @('-XX:+UseZGC')
    $baseArgs   = @("-Xms$InitialRam", "-Xmx$MaxRam", '-jar', $JarName, 'nogui')

    if ($EnableJavaDebug) {
        return $debugFlags + $baseArgs
    } elseif ($EnableOptimizations) {
        if ($UseZGC) {
            return $zgcFlags + $baseArgs
        } else {
            return $g1Flags + $baseArgs
        }
    } else {
        return $baseArgs
    }
}
