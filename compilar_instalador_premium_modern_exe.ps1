$ErrorActionPreference = "Stop"

function Resolve-FirstExistingPath {
    param(
        [string[]]$Candidates
    )

    foreach ($candidate in $Candidates) {
        if ($candidate -and (Test-Path $candidate)) {
            return $candidate
        }
    }

    return $null
}

function Write-Step {
    param(
        [string]$Message
    )

    Write-Host $Message -ForegroundColor Cyan
}

$repoRoot = if ($PSScriptRoot) {
    $PSScriptRoot
}
elseif ($PSCommandPath) {
    Split-Path -Parent $PSCommandPath
}
else {
    (Get-Location).Path
}

$installerScript = Join-Path $repoRoot "installer_output\instalador_premium_modern.ps1"
$buildSource = Join-Path $repoRoot "build\windows\x64\runner\Release"
$outputFile = Join-Path $repoRoot "installer_output\Tienda_Instalador_Premium_Modern.exe"
$pubspecPath = Join-Path $repoRoot "pubspec.yaml"
$pubspecVersion = Select-String -Path $pubspecPath -Pattern '^version:\s*(\d+\.\d+\.\d+)(?:\+(\d+))?' | Select-Object -First 1
if (-not $pubspecVersion) {
    throw "No se pudo leer una version semantica desde pubspec.yaml."
}
$appVersion = $pubspecVersion.Matches[0].Groups[1].Value
$buildNumber = if ($pubspecVersion.Matches[0].Groups[2].Success) { $pubspecVersion.Matches[0].Groups[2].Value } else { "1" }
$temporaryInstallerScript = Join-Path $env:TEMP ("instalador_premium_modern_{0}.ps1" -f [guid]::NewGuid().ToString("N"))
$temporaryManifest = Join-Path $env:TEMP ("tienda_payload_manifest_{0}.json" -f [guid]::NewGuid().ToString("N"))
$iconFile = Resolve-FirstExistingPath -Candidates @(
    (Join-Path $repoRoot "installer_assets\app_icon.ico"),
    (Join-Path $repoRoot "windows\runner\resources\app_icon.ico")
)

Write-Step "[1/7] Configurando clave pública de licencia..."
$licensePublicKey = $env:LICENSE_PUBLIC_KEY
if ([string]::IsNullOrWhiteSpace($licensePublicKey)) {
    $publicKeyPath = Read-Host "Ruta del archivo tienda-public.txt"
    if ([string]::IsNullOrWhiteSpace($publicKeyPath) -or -not (Test-Path -LiteralPath $publicKeyPath -PathType Leaf)) {
        throw "No se encontro el archivo de clave publica indicado."
    }

    $licensePublicKey = [System.IO.File]::ReadAllText($publicKeyPath).Trim()
}

if ([string]::IsNullOrWhiteSpace($licensePublicKey)) {
    throw "LICENSE_PUBLIC_KEY esta vacia."
}

Write-Step "[2/7] Compilando Flutter con la clave pública..."
Push-Location $repoRoot
try {
    & flutter build windows --release "--build-name=$appVersion" "--build-number=$buildNumber" "--dart-define=LICENSE_PUBLIC_KEY=$licensePublicKey"
    if ($LASTEXITCODE -ne 0) {
        throw "Fallo la compilacion de Flutter."
    }
}
finally {
    Pop-Location
}

Write-Step "[3/7] Verificando archivos base..."
if (-not (Test-Path $installerScript)) {
    throw "No se encontro el instalador PowerShell en installer_output\\instalador_premium_modern.ps1"
}

if (-not (Test-Path (Join-Path $buildSource "tienda.exe"))) {
    throw "No se encontro build\\windows\\x64\\runner\\Release\\tienda.exe despues de compilar Flutter."
}

$buildFiles = Get-ChildItem -Path $buildSource -File -Recurse
if (-not $buildFiles) {
    throw "No se encontraron archivos para embebido en $buildSource"
}

$duplicateNames = $buildFiles | Group-Object Name | Where-Object { $_.Count -gt 1 }
if ($duplicateNames) {
    $duplicateList = ($duplicateNames | Select-Object -ExpandProperty Name) -join ", "
    throw "PS2EXE requiere nombres de archivo unicos para embedFiles. Duplicados detectados: $duplicateList"
}

Write-Step "[4/7] Preparando PS2EXE..."
$installedModule = Get-Module -ListAvailable -Name ps2exe | Sort-Object Version -Descending | Select-Object -First 1
if (-not $installedModule -or $installedModule.Version -lt [version]"1.0.17") {
    if (-not (Get-PackageProvider -Name NuGet -ErrorAction SilentlyContinue)) {
        Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -ForceBootstrap -Force -Scope CurrentUser | Out-Null
    }

    try {
        Set-PSRepository -Name PSGallery -InstallationPolicy Trusted -ErrorAction Stop
    }
    catch {
    }

    Install-Module -Name ps2exe -Scope CurrentUser -Force -AllowClobber -MinimumVersion 1.0.17 -Repository PSGallery -SkipPublisherCheck -Confirm:$false | Out-Null
}

Import-Module ps2exe -MinimumVersion 1.0.17 -Force

Write-Step "[5/7] Construyendo payload embebido..."
$embedFiles = @{}
$embeddedResourceNames = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
foreach ($file in $buildFiles) {
    $relativePath = $file.FullName.Substring($buildSource.Length).TrimStart('\\')
    $embedFiles[(".\\payload\\{0}" -f $relativePath)] = $file.FullName
    [void]$embeddedResourceNames.Add($file.Name)
}

$manifestFiles = foreach ($file in $buildFiles) {
    [pscustomobject]@{
        Path = $file.FullName.Substring($buildSource.Length).TrimStart('\\').Replace('\', '/')
        Sha256 = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash
        Length = $file.Length
    }
}
$payloadManifest = [pscustomobject]@{
    Version = $appVersion
    BuildNumber = $buildNumber
    Files = @($manifestFiles)
}
[System.IO.File]::WriteAllText($temporaryManifest, ($payloadManifest | ConvertTo-Json -Depth 5), [System.Text.Encoding]::UTF8)
$embedFiles[".\\payload\\.tienda-payload-manifest.json"] = $temporaryManifest

$installerSource = [System.IO.File]::ReadAllText($installerScript)
if (-not $installerSource.Contains('"__TIENDA_VERSION__"')) {
    throw "No se encontro el marcador de version en el script del instalador."
}
$installerSource = $installerSource.Replace('"__TIENDA_VERSION__"', ('"{0}"' -f $appVersion))
[System.IO.File]::WriteAllText($temporaryInstallerScript, $installerSource, [System.Text.Encoding]::UTF8)

$optionalEmbeds = @(
    @{ Target = ".\\installer_assets\\app_icon.ico"; Candidates = @(
            (Join-Path $repoRoot "installer_assets\app_icon.ico"),
            (Join-Path $repoRoot "windows\runner\resources\app_icon.ico")
        ) },
    @{ Target = ".\\installer_assets\\app_icon.png"; Candidates = @(
            (Join-Path $repoRoot "installer_assets\app_icon.png")
        ) },
    @{ Target = ".\\assets\\image\\AutoRepoLogo.png"; Candidates = @(
            (Join-Path $repoRoot "assets\image\logo.jpg")
        ) },
    @{ Target = ".\\assets\\image\\Logo.jpeg"; Candidates = @(
            (Join-Path $repoRoot "assets\image\Logo.jpg")
        ) }
)

foreach ($embed in $optionalEmbeds) {
    $sourcePath = Resolve-FirstExistingPath -Candidates $embed.Candidates
    if ($sourcePath) {
        $resourceName = [System.IO.Path]::GetFileName($sourcePath)
        if ($embeddedResourceNames.Contains($resourceName)) {
            continue
        }

        $embedFiles[$embed.Target] = $sourcePath
        [void]$embeddedResourceNames.Add($resourceName)
    }
}

Write-Step "[6/7] Compilando instalador EXE..."
$compilerParams = @{
    inputFile = $temporaryInstallerScript
    outputFile = $outputFile
    x64 = $true
    noConsole = $true
    requireAdmin = $true
    winFormsDPIAware = $true
    embedFiles = $embedFiles
    title = "Instalador Tienda"
    description = "Instalador premium WinForms de Tienda"
    company = "DevKosmosyne"
    product = "Tienda"
    version = $appVersion
}

if ($iconFile) {
    $compilerParams.iconFile = $iconFile
}

try {
    Invoke-ps2exe @compilerParams -Verbose
}
finally {
    Remove-Item -LiteralPath $temporaryInstallerScript, $temporaryManifest -Force -ErrorAction SilentlyContinue
}

Write-Step "[7/7] Verificando salida..."
if (-not (Test-Path $outputFile)) {
    throw "PS2EXE no genero el archivo esperado en $outputFile"
}

$generatedFile = Get-Item $outputFile
Write-Host ""
Write-Host "EXE generado correctamente:" -ForegroundColor Green
Write-Host $generatedFile.FullName -ForegroundColor Green
Write-Host (("Tamano: {0:N2} MB" -f ($generatedFile.Length / 1MB))) -ForegroundColor Green
Write-Host ""
Write-Host ("Version incluida: {0} (build {1})" -f $appVersion, $buildNumber) -ForegroundColor Yellow
Write-Host "El instalador valida hashes SHA-256 y reemplaza el arbol de la aplicacion preservando la base de datos en AppData." -ForegroundColor Yellow