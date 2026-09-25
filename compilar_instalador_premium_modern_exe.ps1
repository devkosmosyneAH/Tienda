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
$iconFile = Resolve-FirstExistingPath -Candidates @(
    (Join-Path $repoRoot "installer_assets\app_icon.ico"),
    (Join-Path $repoRoot "windows\runner\resources\app_icon.ico")
)

Write-Step "[1/5] Verificando archivos base..."
if (-not (Test-Path $installerScript)) {
    throw "No se encontro el instalador PowerShell en installer_output\\instalador_premium_modern.ps1"
}

if (-not (Test-Path (Join-Path $buildSource "tienda.exe"))) {
    throw "No se encontro build\\windows\\x64\\runner\\Release\\tienda.exe. Ejecuta flutter build windows --release antes de compilar el EXE."
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

Write-Step "[2/5] Preparando PS2EXE..."
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

Write-Step "[3/5] Construyendo payload embebido..."
$embedFiles = @{}
$embeddedResourceNames = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
foreach ($file in $buildFiles) {
    $relativePath = $file.FullName.Substring($buildSource.Length).TrimStart('\\')
    $embedFiles[(".\\payload\\{0}" -f $relativePath)] = $file.FullName
    [void]$embeddedResourceNames.Add($file.Name)
}

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

Write-Step "[4/5] Compilando instalador EXE..."
$compilerParams = @{
    inputFile = $installerScript
    outputFile = $outputFile
    x64 = $true
    noConsole = $true
    requireAdmin = $true
    winFormsDPIAware = $true
    embedFiles = $embedFiles
    title = "Instalador Tienda SAAS"
    description = "Instalador premium WinForms de Tienda SAAS"
    company = "Tienda SAAS"
    product = "Tienda SAAS"
    version = "2.0.0"
}

if ($iconFile) {
    $compilerParams.iconFile = $iconFile
}

Invoke-ps2exe @compilerParams -Verbose

Write-Step "[5/5] Verificando salida..."
if (-not (Test-Path $outputFile)) {
    throw "PS2EXE no genero el archivo esperado en $outputFile"
}

$generatedFile = Get-Item $outputFile
Write-Host ""
Write-Host "EXE generado correctamente:" -ForegroundColor Green
Write-Host $generatedFile.FullName -ForegroundColor Green
Write-Host (("Tamano: {0:N2} MB" -f ($generatedFile.Length / 1MB))) -ForegroundColor Green
Write-Host ""
Write-Host "Al ejecutarse, el instalador extrae su payload en .\\payload junto al EXE antes de copiar la app a Program Files." -ForegroundColor Yellow