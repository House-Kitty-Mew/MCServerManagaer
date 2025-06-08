$ScriptVersion = '1.0.0'
param (
    [string]$ConfigPath = "$PSScriptRoot\..\config.xml",
    [string]$RollbackPath = "$PSScriptRoot\..\F_META\rollback_history.json",
    [string]$DownloadedDir = "$PSScriptRoot\..\ONLINE_RESOURCES\downloaded",
    [string]$TempDir = "$PSScriptRoot\..\ONLINE_RESOURCES\temp"
)

function Get-RemoteManifest {
    param ($url)
    try {
        return [xml](Invoke-WebRequest -Uri $url -UseBasicParsing).Content
    } catch {
        Write-Error "Failed to fetch remote manifest: $_"
        return $null
    }
}

function Get-FileHashHex {
    param([string]$Path)
    return (Get-FileHash -Path $Path -Algorithm SHA256).Hash
}

function Extract-ZipTo {
    param([string]$ZipPath, [string]$DestPath)
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [System.IO.Compression.ZipFile]::ExtractToDirectory($ZipPath, $DestPath)
}

[xml]$config = Get-Content $ConfigPath
$online = $config.settings.OnlineUpdate
if ($online.Enable -ne "true") {
    Write-Host "Online update disabled in config.xml."
    exit 0
}

$remoteXml = Get-RemoteManifest -url $online.ManifestUrl
if (-not $remoteXml) { exit 1 }

[xml]$localDb = Get-Content "$PSScriptRoot\..\functions.db.xml"
$updates = @()

foreach ($remoteFunc in $remoteXml.functions.function) {
    $name = $remoteFunc.name
    $remoteVersion = $remoteFunc.version
    $zipUrl = $remoteFunc.url
    $remoteHash = $remoteFunc.hash

    $localFunc = $localDb.functions.function | Where-Object { $_.name -eq $name }

    if ($localFunc -and $localFunc.version -ne $remoteVersion) {
        Write-Host "`nUpdate available for $name: $($localFunc.version) -> $remoteVersion"

        $downloadedZip = Join-Path $DownloadedDir "$name-$remoteVersion.zip"
        $tempUnzipPath = Join-Path $TempDir "$name-$remoteVersion"

        Invoke-WebRequest -Uri $zipUrl -OutFile $downloadedZip -UseBasicParsing
        Remove-Item -Recurse -Force $tempUnzipPath -ErrorAction SilentlyContinue
        New-Item -ItemType Directory -Path $tempUnzipPath | Out-Null
        Extract-ZipTo -ZipPath $downloadedZip -DestPath $tempUnzipPath

        $scriptPath = Join-Path "$PSScriptRoot\.." $localFunc.path
        $oldHash = Get-FileHashHex -Path $scriptPath

        # Backup old info in rollback
        $rollback = Get-Content $RollbackPath | ConvertFrom-Json
        $rollback.rollbacks += @{
            name = $name
            timestamp = (Get-Date).ToString("s")
            old_path = $localFunc.path
            old_hash = $oldHash
            old_version = $localFunc.version
        }
        $rollback | ConvertTo-Json -Depth 10 | Set-Content $RollbackPath

        # Overwrite the script
        Copy-Item -Path (Join-Path $tempUnzipPath "$name.ps1") -Destination $scriptPath -Force

        # Update local manifest
        $localFunc.hash = Get-FileHashHex -Path $scriptPath
        $localFunc.version = $remoteVersion
        $localFunc.signature = $remoteFunc.signature
    }
}

$localDb.Save("$PSScriptRoot\..\functions.db.xml")
Write-Host "`nUpdate check complete. Rollback history saved to F_META."
