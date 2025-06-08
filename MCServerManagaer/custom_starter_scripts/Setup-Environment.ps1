$ScriptVersion = '1.0.0'
param (
    [string]$DbPath = "$PSScriptRoot\functions.db.xml",
    [string]$PublicKeyPath = "$PSScriptRoot\public.pem"
)

function Validate-FileHash {
    param (
        [string]$path,
        [string]$expectedHash
    )
    try {
        $actualHash = (Get-FileHash -Path $path -Algorithm SHA256).Hash
        return $actualHash -eq $expectedHash
    } catch {
        return $false
    }
}

function Verify-Signature {
    param (
        [string]$Hash,
        [string]$SignatureHex,
        [string]$PublicKeyPath
    )
    try {
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($Hash)
        $sig = -join ($SignatureHex -split '(.{2})' | Where-Object { $_ }) | ForEach-Object { [Convert]::ToByte($_, 16) }

        $pubKey = [System.IO.File]::ReadAllBytes($PublicKeyPath)
        $rsa = [System.Security.Cryptography.RSA]::Create()
        $rsa.ImportSubjectPublicKeyInfo($pubKey, [ref]0) | Out-Null

        return $rsa.VerifyData($bytes, $sig, [System.Security.Cryptography.HashAlgorithmName]::SHA256, [System.Security.Cryptography.RSASignaturePadding]::Pkcs1)
    } catch {
        Write-Warning "Signature verification error: $_"
        return $false
    }
}

if (-not (Test-Path $DbPath)) {
    Write-Warning "functions.db.xml not found. Would you like to rescan scripts and create it? (Y/N)"
    $res = Read-Host
    if ($res -eq 'Y') {
        & "$PSScriptRoot\Update-FunctionsManifest.ps1"
    } else {
        Write-Error "Cannot continue without manifest validation."
        exit 1
    }
}

if (-not (Test-Path $PublicKeyPath)) {
    Write-Error "Public key missing at $PublicKeyPath"
    exit 1
}

[xml]$db = Get-Content $DbPath
$allValid = $true

foreach ($func in $db.functions.function) {
    $relPath = Join-Path $PSScriptRoot $func.path
    $hash = $func.hash
    $signature = $func.signature

    if (-not (Test-Path $relPath)) {
        Write-Error "Missing file: $($func.path)"
        $allValid = $false
        continue
    }

    if (-not (Validate-FileHash -path $relPath -expectedHash $hash)) {
        Write-Error "Hash mismatch: $($func.path)"
        $allValid = $false
        continue
    }

    if (-not (Verify-Signature -Hash $hash -SignatureHex $signature -PublicKeyPath $PublicKeyPath)) {
        Write-Error "Signature mismatch: $($func.path)"
        $allValid = $false
    }
}

if (-not $allValid) {
    Write-Error "Script integrity check failed. Aborting load."
    exit 1
}

Write-Host "All scripts passed hash and signature verification."
