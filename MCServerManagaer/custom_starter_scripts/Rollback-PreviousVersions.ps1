$ScriptVersion = '1.0.0'
param (
    [string]$RollbackLog = "$PSScriptRoot\..\F_META\rollback_history.json",
    [string]$BasePath = "$PSScriptRoot\.."
)

function Restore-PreviousVersion {
    param (
        [string]$name,
        [string]$targetHash,
        [string]$targetVersion
    )

    $cachedZips = Get-ChildItem -Path "$BasePath\ONLINE_RESOURCES\downloaded" -Filter "$name-*.zip"
    foreach ($zip in $cachedZips) {
        $tempDir = Join-Path "$BasePath\ONLINE_RESOURCES\temp" "$name-rollback"
        Remove-Item -Recurse -Force $tempDir -ErrorAction SilentlyContinue
        New-Item -ItemType Directory -Path $tempDir | Out-Null

        Add-Type -AssemblyName System.IO.Compression.FileSystem
        [System.IO.Compression.ZipFile]::ExtractToDirectory($zip.FullName, $tempDir)

        $candidateScript = Join-Path $tempDir "$name.ps1"
        if (Test-Path $candidateScript) {
            $hash = (Get-FileHash -Path $candidateScript -Algorithm SHA256).Hash
            if ($hash -eq $targetHash) {
                $funcsXml = "$BasePath\functions.db.xml"
                [xml]$doc = Get-Content $funcsXml
                $entry = $doc.functions.function | Where-Object { $_.name -eq $name }
                if ($entry) {
                    $entry.hash = $targetHash
                    $entry.version = $targetVersion
                    $entry.signature = "ROLLED_BACK"
                    $doc.Save($funcsXml)

                    Copy-Item -Path $candidateScript -Destination (Join-Path $BasePath $entry.path) -Force
                    Write-Host "Rolled back $name to version $targetVersion"
                    return $true
                }
            }
        }
    }

    Write-Warning "Failed to rollback $name. Matching version not found in cache."
    return $false
}

if (-not (Test-Path $RollbackLog)) {
    Write-Error "Rollback log not found!"
    exit 1
}

$data = Get-Content $RollbackLog | ConvertFrom-Json
$grouped = $data.rollbacks | Sort-Object timestamp -Descending | Group-Object name

foreach ($g in $grouped) {
    Write-Host "`nRollback candidates for $($g.Name):"
    $index = 0
    foreach ($entry in $g.Group) {
        Write-Host "[$index] $($entry.timestamp) - version: $($entry.old_version)"
        $index++
    }

    $choice = Read-Host "Enter index to rollback $($g.Name) or press Enter to skip"
    if ($choice -ne "") {
        $selected = $g.Group[$choice]
        Restore-PreviousVersion -name $g.Name -targetHash $selected.old_hash -targetVersion $selected.old_version
    }
}
