$ScriptVersion = '1.0.0'
param (
    [string]$ScriptFolder = "$PSScriptRoot\custom_starter_scripts",
    [string]$OutputFile = "$PSScriptRoot\functions.db.xml"
)

function Get-FileHashHex {
    param([string]$Path)
    return (Get-FileHash -Path $Path -Algorithm SHA256).Hash
}

function Extract-Version {
    param([string]$Path)
    $lines = Get-Content $Path
    foreach ($line in $lines) {
        if ($line -match '\$ScriptVersion\s*=\s*["''](.+?)["'']') {
            return $matches[1]
        }
    }
    return "1.0.0"
}

function Sign-Hash {
    param([string]$Hash)
    $privateKeyPath = "$PSScriptRoot\private.pem"
    if (-not (Test-Path $privateKeyPath)) {
        throw "Missing private.pem for signing"
    }

    $bytes = [System.Text.Encoding]::UTF8.GetBytes($Hash)
    $privateKey = [System.IO.File]::ReadAllBytes($privateKeyPath)
    $rsa = [System.Security.Cryptography.RSA]::Create()
    $rsa.ImportRSAPrivateKey($privateKey, [ref]0) | Out-Null
    $signature = $rsa.SignData($bytes, [System.Security.Cryptography.HashAlgorithmName]::SHA256, [System.Security.Cryptography.RSASignaturePadding]::Pkcs1)
    return [BitConverter]::ToString($signature).Replace("-", "")
}

if (Test-Path $OutputFile) {
    [xml]$db = Get-Content $OutputFile
} else {
    [xml]$db = New-Object System.Xml.XmlDocument
    $decl = $db.CreateXmlDeclaration("1.0", "UTF-8", $null)
    $db.AppendChild($decl) | Out-Null
    $functionsNode = $db.CreateElement("functions")
    $db.AppendChild($functionsNode) | Out-Null
}

$existingFuncs = @{}
foreach ($func in $db.functions.function) {
    $existingFuncs[$func.name] = $func
}

$changed = $false
$files = Get-ChildItem -Path $ScriptFolder -Filter *.ps1 -File -Recurse
foreach ($file in $files) {
    $name = $file.BaseName
    $hash = Get-FileHashHex -Path $file.FullName
    $version = Extract-Version -Path $file.FullName
    $signature = Sign-Hash -Hash $hash
    $relPath = $file.FullName.Replace($PSScriptRoot + "\", "")

    if ($existingFuncs.ContainsKey($name)) {
        $entry = $existingFuncs[$name]
        if ($entry.hash -ne $hash -or $entry.version -ne $version) {
            Write-Host "`nDetected change in [$name]:"
            Write-Host "Old hash: $($entry.hash)"
            Write-Host "New hash: $hash"
            Write-Host "Old version: $($entry.version)"
            Write-Host "Script version: $version"

            $choice = Read-Host "Update this entry? (Y/N)"
            if ($choice -eq "Y") {
                $entry.hash = $hash
                $entry.signature = $signature
                $entry.version = $version
                $entry.path = $relPath
                $changed = $true
            }
        }
    } else {
        $newFunc = $db.CreateElement("function")
        $newFunc.SetAttribute("name", $name)
        $newFunc.SetAttribute("path", $relPath)
        $newFunc.SetAttribute("hash", $hash)
        $newFunc.SetAttribute("signature", $signature)
        $newFunc.SetAttribute("version", $version)
        $db.functions.AppendChild($newFunc) | Out-Null
        $changed = $true
        Write-Host "New function added: $name"
    }
}

if ($changed) {
    $db.Save($OutputFile)
    Write-Host "`nManifest updated and saved to $OutputFile"
} else {
    Write-Host "`nNo changes detected. Manifest unchanged."
}
