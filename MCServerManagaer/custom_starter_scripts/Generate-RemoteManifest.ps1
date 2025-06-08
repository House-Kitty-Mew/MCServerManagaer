param (

# Generate key pair if missing
if (-not (Test-Path $PrivateKeyPath)) {
    Write-Host "Private key not found. Generating new RSA key pair..."
    Add-Type -AssemblyName System.Security
    $rsa = [System.Security.Cryptography.RSA]::Create(2048)
    $privateKeyBytes = $rsa.ExportRSAPrivateKey()
    $publicKeyBytes = $rsa.ExportSubjectPublicKeyInfo()

    [System.IO.File]::WriteAllBytes($PrivateKeyPath, $privateKeyBytes)
    $pubPath = $PrivateKeyPath.Replace("private.pem", "public.pem")
    [System.IO.File]::WriteAllBytes($pubPath, $publicKeyBytes)

    Write-Host "Keys saved to: $PrivateKeyPath and $pubPath"
}

    [string]$OutputPath = "$PSScriptRoot\functions_remote.xml",
    [string]$ScriptFolder = "$PSScriptRoot\..\custom_starter_scripts",
    [string]$PrivateKeyPath = "$PSScriptRoot\..\private.pem"
)

function Get-FileHashHex {
    param([string]$Path)
    return (Get-FileHash -Path $Path -Algorithm SHA256).Hash
}

function Extract-Version {
    param([string]$Path)
    $lines = Get-Content $Path -TotalCount 10
    foreach ($line in $lines) {
        if ($line -match '\$ScriptVersion\s*=\s*["''](.+?)["'']') {
            return $matches[1]
        }
    }
    return "1.0.0"
}

function Sign-Hash {
    param (
        [string]$Hash,
        [string]$KeyPath
    )
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($Hash)
    $keyData = [System.IO.File]::ReadAllBytes($KeyPath)
    $rsa = [System.Security.Cryptography.RSA]::Create()
    $rsa.ImportRSAPrivateKey($keyData, [ref]0) | Out-Null
    $signature = $rsa.SignData($bytes, [System.Security.Cryptography.HashAlgorithmName]::SHA256, [System.Security.Cryptography.RSASignaturePadding]::Pkcs1)
    return [BitConverter]::ToString($signature).Replace("-", "")
}

# Build XML
$functions = New-Object System.Xml.XmlDocument
$decl = $functions.CreateXmlDeclaration("1.0", "UTF-8", $null)
$functions.AppendChild($decl) | Out-Null
$root = $functions.CreateElement("functions")
$functions.AppendChild($root)

# Generate entries
$files = Get-ChildItem -Path $ScriptFolder -Filter *.ps1 -File -Recurse
foreach ($file in $files) {
    $hash = Get-FileHashHex -Path $file.FullName
    $version = Extract-Version -Path $file.FullName
    $name = [System.IO.Path]::GetFileNameWithoutExtension($file.Name)
    $signature = Sign-Hash -Hash $hash -KeyPath $PrivateKeyPath

    $func = $functions.CreateElement("function")
    $func.SetAttribute("name", $name)
    $func.SetAttribute("version", $version)
    $func.SetAttribute("hash", $hash)
    $func.SetAttribute("signature", $signature)
    $func.SetAttribute("url", "https://example.com/downloads/$name.zip")

    $root.AppendChild($func) | Out-Null
}

$functions.Save($OutputPath)
Write-Host "Remote manifest saved to $OutputPath"
