param(
    [Parameter(Mandatory = $true)]
    [string]$PublicKeyPath,
    [switch]$BuildOnly
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path -LiteralPath $PublicKeyPath -PathType Leaf)) {
    throw "No se encontro el archivo de clave publica indicado."
}

$licensePublicKey = [System.IO.File]::ReadAllText(
    (Resolve-Path -LiteralPath $PublicKeyPath)
).Trim()
if ([string]::IsNullOrWhiteSpace($licensePublicKey)) {
    throw "El archivo de clave publica esta vacio."
}

$normalizedKey = $licensePublicKey.Replace('-', '+').Replace('_', '/')
switch ($normalizedKey.Length % 4) {
    2 { $normalizedKey += '==' }
    3 { $normalizedKey += '=' }
    1 { throw "La clave publica no tiene un formato Base64URL valido." }
}
try {
    $keyBytes = [Convert]::FromBase64String($normalizedKey)
}
catch {
    throw "La clave publica no tiene un formato Base64URL valido."
}
if ($keyBytes.Length -ne 32) {
    throw "La clave publica Ed25519 debe tener exactamente 32 bytes."
}

$repoRoot = Split-Path -Parent $PSScriptRoot
Push-Location $repoRoot
try {
    if ($BuildOnly) {
        $flutterArguments = @("build", "windows", "--debug")
    }
    else {
        $flutterArguments = @("run", "-d", "windows")
    }
    $flutterArguments += "--dart-define=LICENSE_PUBLIC_KEY=$licensePublicKey"

    & flutter @flutterArguments
    if ($LASTEXITCODE -ne 0) {
        throw "Flutter termino con codigo $LASTEXITCODE."
    }
}
finally {
    Pop-Location
}
