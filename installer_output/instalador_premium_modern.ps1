# ============================================================================
# INSTALADOR PREMIUM - Tienda # Dark Modern UI - Estilo VS Code / Discord / Notion
# PowerShell + WinForms - No requiere WPF
# Version: 2.0.0 - CON INSTALACION REAL X64
# ============================================================================

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.IO.Compression.FileSystem

$ErrorActionPreference = "Stop"

function Get-InstallerHostPath {
    if ($PSCommandPath -and (Test-Path $PSCommandPath)) {
        return $PSCommandPath
    }

    try {
        $processPath = [System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName
        if ($processPath -and (Test-Path $processPath)) {
            return $processPath
        }
    }
    catch {
        return $null
    }

    return $null
}

$script:InstallerHostPath = Get-InstallerHostPath

$script:InstallerScriptRoot = if ($PSScriptRoot) {
    $PSScriptRoot
}
elseif ($script:InstallerHostPath) {
    Split-Path -Parent $script:InstallerHostPath
}
else {
    (Get-Location).Path
}

function Resolve-InstallerPath {
    param(
        [string[]]$RelativeCandidates
    )

    foreach ($relativePath in $RelativeCandidates) {
        $candidatePath = Join-Path $script:InstallerScriptRoot $relativePath
        if (Test-Path $candidatePath) {
            return $candidatePath
        }
    }

    return (Join-Path $script:InstallerScriptRoot $RelativeCandidates[0])
}

function Get-DefaultInstallRoot {
    if ($env:ProgramW6432 -and (Test-Path $env:ProgramW6432)) {
        return $env:ProgramW6432
    }

    if ($env:ProgramFiles -and (Test-Path $env:ProgramFiles)) {
        return $env:ProgramFiles
    }

    $programFilesPath = [Environment]::GetFolderPath("ProgramFiles")
    if ($programFilesPath) {
        return $programFilesPath
    }

    return "C:\Program Files"
}

function Get-DefaultInstallPath {
    return (Join-Path (Get-DefaultInstallRoot) "Tienda")
}

function Test-IsAdministrator {
    $currentIdentity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentIdentity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Start-ElevatedInstaller {
    param(
        [string]$HostPath
    )

    $extension = [System.IO.Path]::GetExtension($HostPath)
    if ([string]::Equals($extension, ".ps1", [System.StringComparison]::OrdinalIgnoreCase)) {
        return Start-Process -FilePath "powershell.exe" -ArgumentList @(
            "-ExecutionPolicy"
            "Bypass"
            "-File"
            ('"{0}"' -f $HostPath)
        ) -Verb RunAs -PassThru -Wait
    }

    return Start-Process -FilePath $HostPath -Verb RunAs -PassThru -Wait
}

function Ensure-InstallerElevation {
    if (Test-IsAdministrator) {
        return
    }

    if (-not $script:InstallerHostPath) {
        throw "Se requieren permisos de administrador para instalar en $(Get-DefaultInstallPath)."
    }

    try {
        $process = Start-ElevatedInstaller -HostPath $script:InstallerHostPath

        exit $process.ExitCode
    }
    catch {
        throw "Se requieren permisos de administrador para instalar en $(Get-DefaultInstallPath)."
    }
}

function Get-RegisteredInstallPath {
    $registryPath = "HKLM:\Software\DevKosmosyne\Tienda"
    try {
        $registeredPath = (Get-ItemProperty -LiteralPath $registryPath -Name InstallLocation -ErrorAction Stop).InstallLocation
        if ($registeredPath -and (Test-Path -LiteralPath $registeredPath -PathType Container)) {
            return $registeredPath
        }
    }
    catch {
    }

    return Get-DefaultInstallPath
}

function Get-InteractiveUserProfilePath {
    $currentProfile = [Environment]::GetFolderPath("UserProfile")
    try {
        $sessionId = (Get-Process -Id $PID).SessionId
        $explorer = Get-CimInstance -ClassName Win32_Process -Filter "Name = 'explorer.exe'" |
            Where-Object { $_.SessionId -eq $sessionId } |
            Select-Object -First 1
        if ($explorer) {
            $owner = Invoke-CimMethod -InputObject $explorer -MethodName GetOwner
            if ($owner.ReturnValue -eq 0) {
                $account = New-Object System.Security.Principal.NTAccount("$($owner.Domain)\$($owner.User)")
                $sid = $account.Translate([System.Security.Principal.SecurityIdentifier]).Value
                $profile = Get-CimInstance -ClassName Win32_UserProfile -Filter "SID = '$sid'"
                if ($profile.LocalPath) {
                    return $profile.LocalPath
                }
            }
        }
    }
    catch {
    }

    return $currentProfile
}

function Get-InteractiveUserAppDataPath {
    $interactiveProfile = Get-InteractiveUserProfilePath
    $currentProfile = [Environment]::GetFolderPath("UserProfile")
    if ([string]::Equals($interactiveProfile, $currentProfile, [System.StringComparison]::OrdinalIgnoreCase) -and $env:APPDATA) {
        return $env:APPDATA
    }

    return Join-Path (Join-Path $interactiveProfile "AppData") "Roaming"
}

# ============================================================================
# CONFIGURACION GLOBAL
# ============================================================================

$global:Config = @{
    AppName = "Tienda"
    Version = "__TIENDA_VERSION__"
    CurrentStep = 1
    InstallPath = (Get-RegisteredInstallPath)
    SourcePath = (Resolve-InstallerPath -RelativeCandidates @("payload", "payload\Release", "distributable\tienda", "..\build\windows\x64\runner\Release", "build\windows\x64\runner\Release"))
    UserProfilePath = (Get-InteractiveUserProfilePath)
    ApplicationDataPath = (Get-InteractiveUserAppDataPath)
    CreateDesktopShortcut = $true
    CreateStartMenuShortcut = $true
    InstallSucceeded = $false
}

function Write-InstallerLog {
    param(
        [string]$Level,
        [string]$Message
    )

    if (-not $script:InstallerLogPath) {
        $logRoot = if ($env:ProgramData) { Join-Path $env:ProgramData "Tienda" } else { Join-Path $env:APPDATA "Tienda" }
        $script:InstallerLogPath = Join-Path $logRoot "installer.log"
    }

    try {
        $logDirectory = Split-Path -Parent $script:InstallerLogPath
        if (-not (Test-Path -LiteralPath $logDirectory)) {
            New-Item -Path $logDirectory -ItemType Directory -Force | Out-Null
        }
        Add-Content -LiteralPath $script:InstallerLogPath -Value ("[{0}] [{1}] {2}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $Level, $Message) -Encoding UTF8
    }
    catch {
    }
}

function Get-InstalledVersion {
    $versionFile = Join-Path $global:Config.InstallPath ".tienda-version"
    if (Test-Path -LiteralPath $versionFile -PathType Leaf) {
        $savedVersion = [System.IO.File]::ReadAllText($versionFile).Trim()
        if ($savedVersion) { return $savedVersion }
    }

    try {
        $registeredVersion = (Get-ItemProperty -LiteralPath "HKLM:\Software\DevKosmosyne\Tienda" -Name DisplayVersion -ErrorAction Stop).DisplayVersion
        if ($registeredVersion) { return $registeredVersion }
    }
    catch {
    }

    $installedExe = Join-Path $global:Config.InstallPath "tienda.exe"
    if (Test-Path -LiteralPath $installedExe -PathType Leaf) {
        $fileVersion = [System.Diagnostics.FileVersionInfo]::GetVersionInfo($installedExe).ProductVersion
        if ($fileVersion) { return $fileVersion }
    }

    return "No detectada"
}

function Get-ApplicationDataDatabasePath {
    if ([string]::IsNullOrWhiteSpace($global:Config.ApplicationDataPath)) {
        throw "No se pudo determinar la carpeta AppData del usuario que inicio la instalacion."
    }

    return Join-Path (Join-Path $global:Config.ApplicationDataPath "Tienda") "tienda.db"
}

function Copy-DatabaseSet {
    param(
        [string]$SourcePath,
        [string]$DestinationPath
    )

    [System.IO.Directory]::CreateDirectory((Split-Path -Parent $DestinationPath)) | Out-Null
    Copy-Item -LiteralPath $SourcePath -Destination $DestinationPath -Force
    foreach ($suffix in @("-wal", "-shm", "-journal")) {
        $sourceSidecar = "$SourcePath$suffix"
        if (Test-Path -LiteralPath $sourceSidecar -PathType Leaf) {
            Copy-Item -LiteralPath $sourceSidecar -Destination "$DestinationPath$suffix" -Force
        }
    }
}

function Protect-ApplicationDatabase {
    $appDataDatabase = Get-ApplicationDataDatabasePath
    $legacyCandidates = @(
        (Join-Path (Join-Path $global:Config.InstallPath "tienda") "tienda.db"),
        (Join-Path $global:Config.InstallPath "tienda.db")
    )
    $existingDatabase = if (Test-Path -LiteralPath $appDataDatabase -PathType Leaf) {
        $appDataDatabase
    }
    else {
        $legacyCandidates | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } | Select-Object -First 1
    }

    if (-not $existingDatabase) {
        Write-InstallerLog -Level "INFO" -Message "No existing database found; the application will initialize it in AppData."
        return
    }

    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $backupDirectory = Join-Path (Split-Path -Parent $appDataDatabase) "backups"
    $backupPath = Join-Path $backupDirectory ("tienda_{0}.db" -f $timestamp)
    $counter = 1
    while (Test-Path -LiteralPath $backupPath) {
        $backupPath = Join-Path $backupDirectory ("tienda_{0}_{1}.db" -f $timestamp, $counter)
        $counter++
    }

    Write-InstallerLog -Level "INFO" -Message "Backing up database from $existingDatabase"
    Copy-DatabaseSet -SourcePath $existingDatabase -DestinationPath $backupPath
    $sourceHash = (Get-FileHash -LiteralPath $existingDatabase -Algorithm SHA256).Hash
    $backupHash = (Get-FileHash -LiteralPath $backupPath -Algorithm SHA256).Hash
    if ($sourceHash -ne $backupHash) {
        throw "La copia de seguridad de la base de datos no coincide con el archivo original."
    }

    if (-not [string]::Equals($existingDatabase, $appDataDatabase, [System.StringComparison]::OrdinalIgnoreCase)) {
        Write-InstallerLog -Level "INFO" -Message "Migrating legacy database to $appDataDatabase"
        Copy-DatabaseSet -SourcePath $existingDatabase -DestinationPath $appDataDatabase
        $migratedHash = (Get-FileHash -LiteralPath $appDataDatabase -Algorithm SHA256).Hash
        if ($sourceHash -ne $migratedHash) {
            throw "La base de datos migrada no coincide con el archivo original."
        }
    }

    $global:Config.DatabasePath = $appDataDatabase
    $global:Config.DatabaseHash = $sourceHash
    Write-InstallerLog -Level "INFO" -Message "Database preserved at $appDataDatabase; backup: $backupPath"
}

function Stop-InstalledTienda {
    $expectedExe = [System.IO.Path]::GetFullPath((Join-Path $global:Config.InstallPath "tienda.exe"))
    $processes = @(Get-Process -Name "tienda" -ErrorAction SilentlyContinue)
    foreach ($process in $processes) {
        $processPath = $null
        try { $processPath = $process.Path } catch {}
        if (-not $processPath) {
            throw "No se pudo verificar la ruta del proceso Tienda (PID $($process.Id)); cierre la aplicacion manualmente e intente otra vez."
        }
        if (-not [string]::Equals([System.IO.Path]::GetFullPath($processPath), $expectedExe, [System.StringComparison]::OrdinalIgnoreCase)) {
            continue
        }

        Write-InstallerLog -Level "INFO" -Message "Closing Tienda.exe (PID $($process.Id))"
        if ($process.MainWindowHandle -ne 0) {
            [void]$process.CloseMainWindow()
        }
        if (-not $process.WaitForExit(15000)) {
            throw "Tienda.exe (PID $($process.Id)) no se cerro en 15 segundos. Guarde su trabajo, cierre la aplicacion e intente otra vez."
        }
    }

    $remaining = @(Get-Process -Name "tienda" -ErrorAction SilentlyContinue)
    foreach ($process in $remaining) {
        try {
            if ([string]::Equals([System.IO.Path]::GetFullPath($process.Path), $expectedExe, [System.StringComparison]::OrdinalIgnoreCase)) {
                throw "Tienda.exe sigue ejecutandose (PID $($process.Id)); no se modificaron los archivos."
            }
        }
        catch {
            if ($_.Exception.Message -like "Tienda.exe sigue ejecutandose*") { throw }
            throw "No se pudo confirmar que Tienda.exe termino; no se modificaron los archivos."
        }
    }

    Write-InstallerLog -Level "INFO" -Message "Tienda.exe closed successfully"
}

function Assert-PayloadManifest {
    $manifestPath = Join-Path $global:Config.SourcePath ".tienda-payload-manifest.json"
    if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
        throw "El payload no contiene .tienda-payload-manifest.json; vuelva a generar el instalador desde la build actual."
    }

    $manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
    if ($manifest.Version -ne $global:Config.Version) {
        throw "La version del payload ($($manifest.Version)) no coincide con la version del instalador ($($global:Config.Version)); se cancela para evitar instalar una build antigua."
    }
    if (-not $manifest.Files -or $manifest.Files.Count -eq 0) {
        throw "El manifiesto del payload no contiene archivos."
    }

    foreach ($entry in $manifest.Files) {
        if ([System.IO.Path]::IsPathRooted($entry.Path) -or $entry.Path -match '(^|/)\.\.(?:/|$)') {
            throw "Ruta insegura en el manifiesto del payload: $($entry.Path)"
        }
        $relativePath = $entry.Path.Replace('/', '\')
        $sourceFile = Join-Path $global:Config.SourcePath $relativePath
        if (-not (Test-Path -LiteralPath $sourceFile -PathType Leaf)) {
            throw "Falta un archivo del payload: $relativePath"
        }
        $actualHash = (Get-FileHash -LiteralPath $sourceFile -Algorithm SHA256).Hash
        if ($actualHash -ne $entry.Sha256) {
            throw "El hash del payload no coincide para $relativePath."
        }
    }

    $exeEntry = $manifest.Files | Where-Object { $_.Path -eq "tienda.exe" } | Select-Object -First 1
    if (-not $exeEntry) {
        throw "El manifiesto no incluye tienda.exe."
    }

    $global:Config.PayloadManifest = $manifest
    $global:Config.ExpectedExeHash = $exeEntry.Sha256
    Write-InstallerLog -Level "INFO" -Message ("Payload {0} validado: {1} archivos; tienda.exe SHA-256 {2}" -f $manifest.Version, $manifest.Files.Count, $exeEntry.Sha256)
}

function Assert-InstalledPayload {
    param([string]$Directory)

    foreach ($entry in $global:Config.PayloadManifest.Files) {
        $relativePath = $entry.Path.Replace('/', '\')
        $installedFile = Join-Path $Directory $relativePath
        if (-not (Test-Path -LiteralPath $installedFile -PathType Leaf)) {
            throw "No se instalo el archivo requerido: $relativePath"
        }
        $actualHash = (Get-FileHash -LiteralPath $installedFile -Algorithm SHA256).Hash
        if ($actualHash -ne $entry.Sha256) {
            throw "El hash instalado no coincide para $relativePath."
        }
    }

    $installedExe = Join-Path $Directory "tienda.exe"
    $exeInfo = Get-Item -LiteralPath $installedExe
    $exeHash = (Get-FileHash -LiteralPath $installedExe -Algorithm SHA256).Hash
    Write-InstallerLog -Level "INFO" -Message ("Verified tienda.exe: SHA-256 {0}; size {1} bytes; modified {2}" -f $exeHash, $exeInfo.Length, $exeInfo.LastWriteTime.ToString("o"))
    if ($exeHash -ne $global:Config.ExpectedExeHash) {
        throw "El ejecutable instalado no es el mismo que el generado desde la build nueva."
    }
    Write-InstallerLog -Level "INFO" -Message ("Verified all {0} application files" -f $global:Config.PayloadManifest.Files.Count)
}

function Install-ApplicationPayload {
    $installPath = [System.IO.Path]::GetFullPath($global:Config.InstallPath)
    $parentPath = Split-Path -Parent $installPath
    if (-not (Test-Path -LiteralPath $parentPath -PathType Container)) {
        New-Item -Path $parentPath -ItemType Directory -Force | Out-Null
    }

    $id = [guid]::NewGuid().ToString("N")
    $stagingPath = Join-Path $parentPath (".Tienda-staging-{0}" -f $id)
    $previousPath = Join-Path $parentPath (".Tienda-previous-{0}" -f $id)
    New-Item -Path $stagingPath -ItemType Directory -Force | Out-Null
    $movedPrevious = $false

    try {
        Write-InstallerLog -Level "INFO" -Message "Removing obsolete application files by mirroring the complete payload"
        Write-InstallerLog -Level "INFO" -Message "Copying new application files to staging"
        & robocopy.exe $global:Config.SourcePath $stagingPath /MIR /COPY:DAT /DCOPY:DAT /R:2 /W:1 /NFL /NDL /NJH /NJS /NP | Out-Null
        $robocopyExitCode = $LASTEXITCODE
        if ($robocopyExitCode -ge 8) {
            throw "Robocopy fallo al preparar la nueva version (codigo $robocopyExitCode)."
        }

        Remove-Item -LiteralPath (Join-Path $stagingPath ".tienda-payload-manifest.json") -Force
        $installerIconPath = Get-InstallerIconPath
        if ($installerIconPath -and (Test-Path -LiteralPath $installerIconPath -PathType Leaf)) {
            Copy-Item -LiteralPath $installerIconPath -Destination (Join-Path $stagingPath "app_icon.ico") -Force
        }
        Assert-InstalledPayload -Directory $stagingPath

        if (Test-Path -LiteralPath $installPath -PathType Container) {
            Move-Item -LiteralPath $installPath -Destination $previousPath
            $movedPrevious = $true
        }
        Move-Item -LiteralPath $stagingPath -Destination $installPath
        Set-Content -LiteralPath (Join-Path $installPath ".tienda-version") -Value $global:Config.Version -Encoding ASCII
        Assert-InstalledPayload -Directory $installPath

        if ($global:Config.DatabasePath) {
            $installedDatabaseHash = (Get-FileHash -LiteralPath $global:Config.DatabasePath -Algorithm SHA256).Hash
            if ($installedDatabaseHash -ne $global:Config.DatabaseHash) {
                throw "La base de datos de AppData cambio durante la actualizacion."
            }
            Write-InstallerLog -Level "INFO" -Message "Database preserved and verified in AppData"
        }

        $registryPath = "HKLM:\Software\DevKosmosyne\Tienda"
        New-Item -Path $registryPath -Force | Out-Null
        Set-ItemProperty -LiteralPath $registryPath -Name InstallLocation -Value $installPath
        Set-ItemProperty -LiteralPath $registryPath -Name DisplayVersion -Value $global:Config.Version

        if ($movedPrevious) {
            Remove-Item -LiteralPath $previousPath -Recurse -Force
        }
        Write-InstallerLog -Level "INFO" -Message "Application files verified; update completed successfully"
    }
    catch {
        $installError = $_
        if (Test-Path -LiteralPath $installPath -PathType Container) {
            Remove-Item -LiteralPath $installPath -Recurse -Force -ErrorAction SilentlyContinue
        }
        if ($movedPrevious) {
            if (Test-Path -LiteralPath $previousPath -PathType Container) {
                Move-Item -LiteralPath $previousPath -Destination $installPath -ErrorAction SilentlyContinue
            }
        }
        throw $installError
    }
    finally {
        if (Test-Path -LiteralPath $stagingPath -PathType Container) {
            Remove-Item -LiteralPath $stagingPath -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

function Get-InstallerIconPath {
    $iconCandidates = @(
        "..\installer_assets\app_icon.ico",
        "installer_assets\app_icon.ico",
        "..\windows\runner\resources\app_icon.ico",
        "windows\runner\resources\app_icon.ico"
    )

    return Resolve-InstallerPath -RelativeCandidates $iconCandidates
}

function Get-InstallerLogoPath {
    $logoCandidates = @(
        "..\installer_assets\app_icon.png",
        "installer_assets\app_icon.png",
        "payload\data\flutter_assets\assets\image\AutoRepoLogo.png",
        "payload\data\flutter_assets\assets\image\Logo.jpeg",
        "..\assets\image\AutoRepoLogo.png",
        "assets\image\AutoRepoLogo.png",
        "..\assets\image\Logo.jpeg",
        "assets\image\Logo.jpeg"
    )

    foreach ($relativePath in $logoCandidates) {
        $candidatePath = Join-Path $script:InstallerScriptRoot $relativePath
        if (Test-Path $candidatePath) {
            return $candidatePath
        }
    }

    return $null
}

# ============================================================================
# PALETA DE COLORES PREMIUM DARK
# ============================================================================

$global:Colors = @{
    Background = [System.Drawing.Color]::FromArgb(18, 18, 18)      # #121212
    Panel = [System.Drawing.Color]::FromArgb(30, 30, 30)           # #1E1E1E
    Border = [System.Drawing.Color]::FromArgb(42, 42, 42)          # #2A2A2A
    Sidebar = [System.Drawing.Color]::FromArgb(24, 24, 24)         # #181818
    AccentOrange = [System.Drawing.Color]::FromArgb(255, 0, 0)   # #FF0000
    TextPrimary = [System.Drawing.Color]::FromArgb(255, 255, 255)  # #FFFFFF
    TextSecondary = [System.Drawing.Color]::FromArgb(170, 170, 170) # #AAAAAA
    Success = [System.Drawing.Color]::FromArgb(76, 175, 80)        # #4CAF50
    ButtonHover = [System.Drawing.Color]::FromArgb(255, 0, 0)   # Hover effect
}

# ============================================================================
# COMPONENTES VISUALES REUTILIZABLES
# ============================================================================

function New-ModernButton {
    param(
        [string]$Text,
        [int]$X,
        [int]$Y,
        [int]$Width = 120,
        [int]$Height = 40,
        [bool]$IsPrimary = $false,
        [scriptblock]$OnClick
    )
    
    $button = New-Object System.Windows.Forms.Button
    $button.Text = $Text
    $button.Location = New-Object System.Drawing.Point($X, $Y)
    $button.Size = New-Object System.Drawing.Size($Width, $Height)
    $button.FlatStyle = 'Flat'
    $button.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Regular)
    $button.Cursor = [System.Windows.Forms.Cursors]::Hand
    
    if ($IsPrimary) {
        $button.BackColor = $global:Colors.AccentOrange
        $button.ForeColor = $global:Colors.TextPrimary
        $button.FlatAppearance.BorderSize = 0
    } else {
        $button.BackColor = $global:Colors.Panel
        $button.ForeColor = $global:Colors.TextSecondary
        $button.FlatAppearance.BorderColor = $global:Colors.Border
        $button.FlatAppearance.BorderSize = 1
    }
    
    # Hover effects
    $mouseEnterHandler = {
        if ($IsPrimary) {
            $this.BackColor = $global:Colors.ButtonHover
        } else {
            $this.BackColor = $global:Colors.Border
        }
    }.GetNewClosure()
    $button.Add_MouseEnter($mouseEnterHandler)
    
    $mouseLeaveHandler = {
        if ($IsPrimary) {
            $this.BackColor = $global:Colors.AccentOrange
        } else {
            $this.BackColor = $global:Colors.Panel
        }
    }.GetNewClosure()
    $button.Add_MouseLeave($mouseLeaveHandler)
    
    if ($OnClick) {
        $button.Add_Click($OnClick)
    }
    
    return $button
}

function New-ModernLabel {
    param(
        [string]$Text,
        [int]$X,
        [int]$Y,
        [int]$Width = 400,
        [int]$Height = 30,
        [int]$FontSize = 10,
        [bool]$IsBold = $false,
        [bool]$IsPrimary = $true
    )
    
    $label = New-Object System.Windows.Forms.Label
    $label.Text = $Text
    $label.Location = New-Object System.Drawing.Point($X, $Y)
    $label.Size = New-Object System.Drawing.Size($Width, $Height)
    $label.AutoSize = $false
    
    $fontStyle = if ($IsBold) { [System.Drawing.FontStyle]::Bold } else { [System.Drawing.FontStyle]::Regular }
    $label.Font = New-Object System.Drawing.Font("Segoe UI", $FontSize, $fontStyle)
    
    $label.ForeColor = if ($IsPrimary) { $global:Colors.TextPrimary } else { $global:Colors.TextSecondary }
    $label.BackColor = [System.Drawing.Color]::Transparent
    
    return $label
}

function New-SectionTitle {
    param(
        [string]$Text,
        [int]$X,
        [int]$Y,
        [int]$Width = 500
    )
    
    return New-ModernLabel -Text $Text -X $X -Y $Y -Width $Width -Height 40 -FontSize 18 -IsBold $true -IsPrimary $true
}

function New-ModernPanel {
    param(
        [int]$X,
        [int]$Y,
        [int]$Width,
        [int]$Height,
        [bool]$HasBorder = $true
    )
    
    $panel = New-Object System.Windows.Forms.Panel
    $panel.Location = New-Object System.Drawing.Point($X, $Y)
    $panel.Size = New-Object System.Drawing.Size($Width, $Height)
    $panel.BackColor = $global:Colors.Panel
    
    if ($HasBorder) {
        $panel.BorderStyle = 'None'
        $panel.Add_Paint({
            param($sender, $e)
            $pen = New-Object System.Drawing.Pen($global:Colors.Border, 1)
            $e.Graphics.DrawRectangle($pen, 0, 0, $sender.Width - 1, $sender.Height - 1)
            $pen.Dispose()
        })
    }
    
    return $panel
}

function New-ModernTextBox {
    param(
        [int]$X,
        [int]$Y,
        [int]$Width = 400,
        [int]$Height = 32,
        [string]$Text = ""
    )
    
    $textBox = New-Object System.Windows.Forms.TextBox
    $textBox.Location = New-Object System.Drawing.Point($X, $Y)
    $textBox.Size = New-Object System.Drawing.Size($Width, $Height)
    $textBox.Text = $Text
    $textBox.Font = New-Object System.Drawing.Font("Segoe UI", 10)
    $textBox.BackColor = $global:Colors.Panel
    $textBox.ForeColor = $global:Colors.TextPrimary
    $textBox.BorderStyle = 'FixedSingle'
    
    return $textBox
}

function New-ModernCheckBox {
    param(
        [string]$Text,
        [int]$X,
        [int]$Y,
        [int]$Width = 400,
        [bool]$Checked = $false
    )
    
    $checkBox = New-Object System.Windows.Forms.CheckBox
    $checkBox.Text = $Text
    $checkBox.Location = New-Object System.Drawing.Point($X, $Y)
    $checkBox.Size = New-Object System.Drawing.Size($Width, 28)
    $checkBox.Checked = $Checked
    $checkBox.Font = New-Object System.Drawing.Font("Segoe UI", 10)
    $checkBox.ForeColor = $global:Colors.TextPrimary
    $checkBox.BackColor = $global:Colors.Panel
    $checkBox.FlatStyle = 'Flat'
    $checkBox.UseVisualStyleBackColor = $false
    $checkBox.FlatAppearance.BorderColor = $global:Colors.TextSecondary
    $checkBox.FlatAppearance.CheckedBackColor = $global:Colors.AccentOrange
    $checkBox.FlatAppearance.MouseOverBackColor = $global:Colors.Border
    $checkBox.FlatAppearance.MouseDownBackColor = $global:Colors.Border
    $checkBox.Cursor = [System.Windows.Forms.Cursors]::Hand
    
    return $checkBox
}

function New-ModernProgressBar {
    param(
        [int]$X,
        [int]$Y,
        [int]$Width = 500,
        [int]$Height = 8
    )
    
    $progressBar = New-Object System.Windows.Forms.ProgressBar
    $progressBar.Location = New-Object System.Drawing.Point($X, $Y)
    $progressBar.Size = New-Object System.Drawing.Size($Width, $Height)
    $progressBar.Style = 'Continuous'
    $progressBar.ForeColor = $global:Colors.AccentOrange
    
    return $progressBar
}

# ============================================================================
# SIDEBAR MODERNA CON INDICADORES DE PASOS
# ============================================================================

function New-ModernSidebar {
    $sidebar = New-Object System.Windows.Forms.Panel
    $sidebar.Location = New-Object System.Drawing.Point(0, 0)
    $sidebar.Size = New-Object System.Drawing.Size(220, 600)
    $sidebar.BackColor = $global:Colors.Sidebar
    $sidebar.Dock = 'Left'
    
    # Logo / Branding
    $logoTop = 20
    $logoBottom = 108
    $logoPath = Get-InstallerLogoPath

    if ($logoPath) {
        try {
            $logoImage = [System.Drawing.Image]::FromFile($logoPath)
            $pictureLogo = New-Object System.Windows.Forms.PictureBox
            $pictureLogo.Location = New-Object System.Drawing.Point(10, $logoTop)
            $pictureLogo.Size = New-Object System.Drawing.Size(200, 88)
            $pictureLogo.SizeMode = [System.Windows.Forms.PictureBoxSizeMode]::Zoom
            $pictureLogo.BackColor = $global:Colors.Sidebar
            $pictureLogo.Image = $logoImage
            $sidebar.Controls.Add($pictureLogo)
        }
        catch {
            $logoPath = $null
        }
    }

    if (-not $logoPath) {
        $lblLogo = New-Object System.Windows.Forms.Label
        $lblLogo.Text = "[GE]"
        $lblLogo.Location = New-Object System.Drawing.Point(20, 30)
        $lblLogo.Size = New-Object System.Drawing.Size(180, 50)
        $lblLogo.Font = New-Object System.Drawing.Font("Segoe UI", 24, [System.Drawing.FontStyle]::Bold)
        $lblLogo.ForeColor = $global:Colors.AccentOrange
        $lblLogo.BackColor = [System.Drawing.Color]::Transparent
        $lblLogo.TextAlign = 'MiddleCenter'
        $sidebar.Controls.Add($lblLogo)
        $logoBottom = 80
    }
    
    $lblBrand = New-Object System.Windows.Forms.Label
    $lblBrand.Text = "Tienda"
    $lblBrand.Location = New-Object System.Drawing.Point(20, ($logoBottom + 6))
    $lblBrand.Size = New-Object System.Drawing.Size(180, 30)
    $lblBrand.Font = New-Object System.Drawing.Font("Segoe UI", 13, [System.Drawing.FontStyle]::Bold)
    $lblBrand.ForeColor = $global:Colors.TextPrimary
    $lblBrand.BackColor = [System.Drawing.Color]::Transparent
    $lblBrand.TextAlign = 'MiddleCenter'
    $sidebar.Controls.Add($lblBrand)
    
    $lblVersion = New-Object System.Windows.Forms.Label
    $lblVersion.Text = "v$($global:Config.Version)"
    $lblVersion.Location = New-Object System.Drawing.Point(20, ($logoBottom + 36))
    $lblVersion.Size = New-Object System.Drawing.Size(180, 20)
    $lblVersion.Font = New-Object System.Drawing.Font("Segoe UI", 9)
    $lblVersion.ForeColor = $global:Colors.TextSecondary
    $lblVersion.BackColor = [System.Drawing.Color]::Transparent
    $lblVersion.TextAlign = 'MiddleCenter'
    $sidebar.Controls.Add($lblVersion)
    
    # Separador
    $separator = New-Object System.Windows.Forms.Panel
    $separator.Location = New-Object System.Drawing.Point(30, ($logoBottom + 76))
    $separator.Size = New-Object System.Drawing.Size(160, 1)
    $separator.BackColor = $global:Colors.Border
    $sidebar.Controls.Add($separator)
    
    # Pasos del instalador
    $steps = @(
        @{Number=1; Text="Bienvenida"; Y=($logoBottom + 106)},
        @{Number=2; Text="Directorio"; Y=($logoBottom + 156)},
        @{Number=3; Text="Componentes"; Y=($logoBottom + 206)},
        @{Number=4; Text="Instalacion"; Y=($logoBottom + 256)},
        @{Number=5; Text="Finalizar"; Y=($logoBottom + 306)}
    )
    
    foreach ($step in $steps) {
        $stepPanel = New-Object System.Windows.Forms.Panel
        $stepPanel.Location = New-Object System.Drawing.Point(30, $step.Y)
        $stepPanel.Size = New-Object System.Drawing.Size(160, 40)
        $stepPanel.BackColor = [System.Drawing.Color]::Transparent
        $stepPanel.Tag = $step.Number
        
        $numLabel = New-Object System.Windows.Forms.Label
        $numLabel.Text = $step.Number.ToString()
        $numLabel.Location = New-Object System.Drawing.Point(0, 8)
        $numLabel.Size = New-Object System.Drawing.Size(30, 24)
        $numLabel.Font = New-Object System.Drawing.Font("Segoe UI", 11, [System.Drawing.FontStyle]::Bold)
        $numLabel.TextAlign = 'MiddleCenter'
        $numLabel.BackColor = $global:Colors.Panel
        $numLabel.Tag = "stepNumber"
        $stepPanel.Controls.Add($numLabel)
        
        $textLabel = New-Object System.Windows.Forms.Label
        $textLabel.Text = $step.Text
        $textLabel.Location = New-Object System.Drawing.Point(40, 8)
        $textLabel.Size = New-Object System.Drawing.Size(120, 24)
        $textLabel.Font = New-Object System.Drawing.Font("Segoe UI", 10)
        $textLabel.ForeColor = $global:Colors.TextSecondary
        $textLabel.BackColor = [System.Drawing.Color]::Transparent
        $textLabel.TextAlign = 'MiddleLeft'
        $textLabel.Tag = "stepText"
        $stepPanel.Controls.Add($textLabel)
        
        $sidebar.Controls.Add($stepPanel)
    }
    
    # Footer del sidebar
    $lblFooter = New-Object System.Windows.Forms.Label
    $lblFooter.Text = "@ 2026 Tienda`nTodos los derechos reservados"
    $lblFooter.Location = New-Object System.Drawing.Point(20, 520)
    $lblFooter.Size = New-Object System.Drawing.Size(180, 50)
    $lblFooter.Font = New-Object System.Drawing.Font("Segoe UI", 8)
    $lblFooter.ForeColor = $global:Colors.TextSecondary
    $lblFooter.BackColor = [System.Drawing.Color]::Transparent
    $lblFooter.TextAlign = 'MiddleCenter'
    $sidebar.Controls.Add($lblFooter)
    
    $sidebar.Tag = "sidebar"
    return $sidebar
}

function Update-SidebarStep {
    param($form, [int]$currentStep)
    
    $sidebar = $form.Controls | Where-Object { $_.Tag -eq "sidebar" }
    if (-not $sidebar) { return }
    
    foreach ($control in $sidebar.Controls) {
        if ($control -is [System.Windows.Forms.Panel] -and $control.Tag -is [int]) {
            $stepNum = [int]$control.Tag
            $numLabel = $control.Controls | Where-Object { $_.Tag -eq "stepNumber" }
            $textLabel = $control.Controls | Where-Object { $_.Tag -eq "stepText" }
            
            if ($stepNum -eq $currentStep) {
                $numLabel.BackColor = $global:Colors.AccentOrange
                $numLabel.ForeColor = $global:Colors.TextPrimary
                $textLabel.ForeColor = $global:Colors.TextPrimary
                $textLabel.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
            }
            elseif ($stepNum -lt $currentStep) {
                $numLabel.BackColor = $global:Colors.Success
                $numLabel.ForeColor = $global:Colors.TextPrimary
                $textLabel.ForeColor = $global:Colors.TextSecondary
                $textLabel.Font = New-Object System.Drawing.Font("Segoe UI", 10)
            }
            else {
                $numLabel.BackColor = $global:Colors.Panel
                $numLabel.ForeColor = $global:Colors.TextSecondary
                $textLabel.ForeColor = $global:Colors.TextSecondary
                $textLabel.Font = New-Object System.Drawing.Font("Segoe UI", 10)
            }
        }
    }
}

# ============================================================================
# VENTANA PRINCIPAL MODERNA
# ============================================================================

function New-ModernMainWindow {
    $form = New-Object System.Windows.Forms.Form
    $form.Text = "Instalador - Tienda"
    $form.Size = New-Object System.Drawing.Size(900, 600)
    $form.StartPosition = "CenterScreen"
    $form.FormBorderStyle = "FixedDialog"
    $form.MaximizeBox = $false
    $form.MinimizeBox = $true
    $form.BackColor = $global:Colors.Background
    $form.Font = New-Object System.Drawing.Font("Segoe UI", 10)

    $iconPath = Get-InstallerIconPath
    if ($iconPath) {
        try {
            $form.Icon = New-Object System.Drawing.Icon($iconPath)
        }
        catch {
            # Si el .ico no se puede cargar, el instalador sigue funcionando.
        }
    }
    
    # Agregar sidebar
    $sidebar = New-ModernSidebar
    $form.Controls.Add($sidebar)
    
    return $form
}

function New-ContentPanel {
    param($form)
    
    # Clear existing content panel
    $existingPanel = $form.Controls | Where-Object { $_.Tag -eq "contentPanel" }
    if ($existingPanel) {
        $form.Controls.Remove($existingPanel)
        $existingPanel.Dispose()
    }
    
    $panel = New-Object System.Windows.Forms.Panel
    $panel.Location = New-Object System.Drawing.Point(220, 0)
    $panel.Size = New-Object System.Drawing.Size(680, 600)
    $panel.BackColor = $global:Colors.Background
    $panel.Tag = "contentPanel"
    
    return $panel
}

# ============================================================================
# PAGINA 1: BIENVENIDA PREMIUM
# ============================================================================

function Show-WelcomePage {
    param($form)
    
    $global:Config.CurrentStep = 1
    Update-SidebarStep -form $form -currentStep 1
    
    $content = New-ContentPanel -form $form
    
    # Header
    $lblTitle = New-SectionTitle -Text "Bienvenido" -X 40 -Y 50 -Width 600
    $content.Controls.Add($lblTitle)
    
    $lblSubtitle = New-ModernLabel -Text "Sistema de Gestion Empresarial Premium" -X 40 -Y 95 -Width 600 -Height 25 -FontSize 12 -IsBold $false -IsPrimary $false
    $content.Controls.Add($lblSubtitle)
    
    # Card con informacion
    $cardPanel = New-ModernPanel -X 40 -Y 150 -Width 600 -Height 280
    $content.Controls.Add($cardPanel)
    
    $lblDescription = New-ModernLabel -Text "Este asistente le guiara a traves del proceso de instalacion." -X 30 -Y 25 -Width 540 -Height 30 -FontSize 11 -IsPrimary $true
    $cardPanel.Controls.Add($lblDescription)
    
    $lblFeatures = New-ModernLabel -Text "La aplicacion incluye:" -X 30 -Y 70 -Width 540 -Height 25 -FontSize 11 -IsBold $true -IsPrimary $true
    $cardPanel.Controls.Add($lblFeatures)
    
    # Features list
    $features = @(
        @{Icon="[X]"; Text="Gestion completa de inventario"; Y=110},
        @{Icon="[X]"; Text="Control de usuarios y permisos"; Y=145},
        @{Icon="[X]"; Text="Respaldos automaticos"; Y=180},
        @{Icon="[X]"; Text="Interfaz moderna y facil de usar"; Y=215}
    )
    
    foreach ($feature in $features) {
        $iconLabel = New-ModernLabel -Text $feature.Icon -X 30 -Y $feature.Y -Width 30 -Height 25 -FontSize 12 -IsBold $true -IsPrimary $false
        $iconLabel.ForeColor = $global:Colors.Success
        $cardPanel.Controls.Add($iconLabel)
        
        $textLabel = New-ModernLabel -Text $feature.Text -X 70 -Y $feature.Y -Width 500 -Height 25 -FontSize 10 -IsPrimary $true
        $cardPanel.Controls.Add($textLabel)
    }
    
    # Botones
    $btnNext = New-ModernButton -Text "Siguiente >" -X 500 -Y 500 -Width 140 -Height 44 -IsPrimary $true -OnClick ({
        Show-DirectoryPage -form $form
    }.GetNewClosure())
    $content.Controls.Add($btnNext)
    
    $btnCancel = New-ModernButton -Text "Cancelar" -X 340 -Y 500 -Width 140 -Height 44 -IsPrimary $false -OnClick ({
        $result = [System.Windows.Forms.MessageBox]::Show(
            "Esta seguro que desea cancelar la instalacion?",
            "Cancelar Instalacion",
            [System.Windows.Forms.MessageBoxButtons]::YesNo,
            [System.Windows.Forms.MessageBoxIcon]::Question
        )
        if ($result -eq 'Yes') { $form.Close() }
    }.GetNewClosure())
    $content.Controls.Add($btnCancel)
    
    $form.Controls.Add($content)
}

# ============================================================================
# PAGINA 2: SELECCION DE DIRECTORIO
# ============================================================================

function Show-DirectoryPage {
    param($form)
    
    $global:Config.CurrentStep = 2
    Update-SidebarStep -form $form -currentStep 2
    
    $content = New-ContentPanel -form $form
    
    # Header
    $lblTitle = New-SectionTitle -Text "Seleccionar Ubicacion" -X 40 -Y 50 -Width 600
    $content.Controls.Add($lblTitle)
    
    $lblSubtitle = New-ModernLabel -Text "Elija donde desea instalar la aplicacion" -X 40 -Y 95 -Width 600 -Height 25 -FontSize 12 -IsBold $false -IsPrimary $false
    $content.Controls.Add($lblSubtitle)
    
    # Card de directorio
    $cardPanel = New-ModernPanel -X 40 -Y 150 -Width 600 -Height 180
    $content.Controls.Add($cardPanel)
    
    $lblPath = New-ModernLabel -Text "Directorio de instalacion:" -X 30 -Y 30 -Width 540 -Height 25 -FontSize 10 -IsBold $true -IsPrimary $true
    $cardPanel.Controls.Add($lblPath)
    
    $txtPath = New-ModernTextBox -X 30 -Y 65 -Width 450 -Height 36 -Text $global:Config.InstallPath
    $cardPanel.Controls.Add($txtPath)
    
    $btnBrowse = New-ModernButton -Text "..." -X 490 -Y 65 -Width 80 -Height 36 -IsPrimary $false -OnClick ({
        $folderDialog = New-Object System.Windows.Forms.FolderBrowserDialog
        $folderDialog.Description = "Seleccione el directorio de instalacion"
        $folderDialog.SelectedPath = $txtPath.Text
        
        if ($folderDialog.ShowDialog() -eq 'OK') {
            $selectedPath = $folderDialog.SelectedPath
            if ([string]::Equals([System.IO.Path]::GetFileName($selectedPath), $global:Config.AppName, [System.StringComparison]::OrdinalIgnoreCase)) {
                $txtPath.Text = $selectedPath
            }
            else {
                $txtPath.Text = Join-Path $selectedPath $global:Config.AppName
            }
            $global:Config.InstallPath = $txtPath.Text
        }
    }.GetNewClosure())
    $cardPanel.Controls.Add($btnBrowse)
    
    # Info de espacio
    $lblSpace = New-ModernLabel -Text "Espacio requerido: ~250 MB" -X 30 -Y 115 -Width 540 -Height 25 -FontSize 9 -IsPrimary $false
    $cardPanel.Controls.Add($lblSpace)
    
    try {
        $drive = [System.IO.Path]::GetPathRoot($global:Config.InstallPath)
        $driveInfo = New-Object System.IO.DriveInfo($drive)
        $freeSpaceGB = [math]::Round($driveInfo.AvailableFreeSpace / 1GB, 2)
        $lblAvailable = New-ModernLabel -Text "Espacio disponible: $freeSpaceGB GB" -X 30 -Y 140 -Width 540 -Height 25 -FontSize 9 -IsPrimary $false
        $cardPanel.Controls.Add($lblAvailable)
    } catch {
        # Ignore error if drive not accessible
    }
    
    # Botones
    $btnBack = New-ModernButton -Text "< Anterior" -X 180 -Y 500 -Width 140 -Height 44 -IsPrimary $false -OnClick ({
        Show-WelcomePage -form $form
    }.GetNewClosure())
    $content.Controls.Add($btnBack)
    
    $btnNext = New-ModernButton -Text "Siguiente >" -X 500 -Y 500 -Width 140 -Height 44 -IsPrimary $true -OnClick ({
        $global:Config.InstallPath = $txtPath.Text
        Show-ComponentsPage -form $form
    }.GetNewClosure())
    $content.Controls.Add($btnNext)
    
    $btnCancel = New-ModernButton -Text "Cancelar" -X 340 -Y 500 -Width 140 -Height 44 -IsPrimary $false -OnClick ({
        $result = [System.Windows.Forms.MessageBox]::Show(
            "Esta seguro que desea cancelar la instalacion?",
            "Cancelar Instalacion",
            [System.Windows.Forms.MessageBoxButtons]::YesNo,
            [System.Windows.Forms.MessageBoxIcon]::Question
        )
        if ($result -eq 'Yes') { $form.Close() }
    }.GetNewClosure())
    $content.Controls.Add($btnCancel)
    
    $form.Controls.Add($content)
}

# ============================================================================
# PAGINA 3: COMPONENTES
# ============================================================================

function Show-ComponentsPage {
    param($form)
    
    $global:Config.CurrentStep = 3
    Update-SidebarStep -form $form -currentStep 3
    
    $content = New-ContentPanel -form $form
    
    # Header
    $lblTitle = New-SectionTitle -Text "Componentes Adicionales" -X 40 -Y 50 -Width 600
    $content.Controls.Add($lblTitle)
    
    $lblSubtitle = New-ModernLabel -Text "Personalice su instalacion" -X 40 -Y 95 -Width 600 -Height 25 -FontSize 12 -IsBold $false -IsPrimary $false
    $content.Controls.Add($lblSubtitle)
    
    # Card de componentes
    $cardPanel = New-ModernPanel -X 40 -Y 150 -Width 600 -Height 160
    $content.Controls.Add($cardPanel)
    
    $lblComponents = New-ModernLabel -Text "Seleccione los accesos directos que desea crear:" -X 30 -Y 25 -Width 540 -Height 25 -FontSize 10 -IsBold $true -IsPrimary $true
    $cardPanel.Controls.Add($lblComponents)
    
    $chkDesktop = New-ModernCheckBox -Text "Crear acceso directo en el escritorio" -X 30 -Y 65 -Width 540 -Checked $global:Config.CreateDesktopShortcut
    $chkDesktop.Add_CheckedChanged({ $global:Config.CreateDesktopShortcut = $chkDesktop.Checked }.GetNewClosure())
    $cardPanel.Controls.Add($chkDesktop)
    
    $chkStartMenu = New-ModernCheckBox -Text "Crear accesos directos en el menu de inicio" -X 30 -Y 105 -Width 540 -Checked $global:Config.CreateStartMenuShortcut
    $chkStartMenu.Add_CheckedChanged({ $global:Config.CreateStartMenuShortcut = $chkStartMenu.Checked }.GetNewClosure())
    $cardPanel.Controls.Add($chkStartMenu)
    
    # Card de resumen
    $summaryPanel = New-ModernPanel -X 40 -Y 330 -Width 600 -Height 140
    $content.Controls.Add($summaryPanel)
    
    $lblSummaryTitle = New-ModernLabel -Text "Resumen de Instalacion" -X 30 -Y 20 -Width 540 -Height 25 -FontSize 11 -IsBold $true -IsPrimary $true
    $summaryPanel.Controls.Add($lblSummaryTitle)
    
    $lblSummary = New-ModernLabel -Text "* Aplicacion: Tienda v$($global:Config.Version)`n* Ubicacion: $($global:Config.InstallPath)`n* Componentes: Segun seleccion" -X 30 -Y 55 -Width 540 -Height 70 -FontSize 9 -IsPrimary $false
    $summaryPanel.Controls.Add($lblSummary)
    
    # Botones
    $btnBack = New-ModernButton -Text "< Anterior" -X 180 -Y 500 -Width 140 -Height 44 -IsPrimary $false -OnClick ({
        Show-DirectoryPage -form $form
    }.GetNewClosure())
    $content.Controls.Add($btnBack)
    
    $btnInstall = New-ModernButton -Text "Instalar" -X 500 -Y 500 -Width 140 -Height 44 -IsPrimary $true -OnClick ({
        Show-InstallPage -form $form
    }.GetNewClosure())
    $content.Controls.Add($btnInstall)
    
    $btnCancel = New-ModernButton -Text "Cancelar" -X 340 -Y 500 -Width 140 -Height 44 -IsPrimary $false -OnClick ({
        $result = [System.Windows.Forms.MessageBox]::Show(
            "Esta seguro que desea cancelar la instalacion?",
            "Cancelar Instalacion",
            [System.Windows.Forms.MessageBoxButtons]::YesNo,
            [System.Windows.Forms.MessageBoxIcon]::Question
        )
        if ($result -eq 'Yes') { $form.Close() }
    }.GetNewClosure())
    $content.Controls.Add($btnCancel)
    
    $form.Controls.Add($content)
}

# ============================================================================
# PAGINA 4: INSTALACION EN PROGRESO - CON LOGICA REAL X64
# ============================================================================

function Show-InstallPage {
    param($form)
    
    $global:Config.CurrentStep = 4
    Update-SidebarStep -form $form -currentStep 4
    
    $content = New-ContentPanel -form $form
    
    # Header
    $lblTitle = New-SectionTitle -Text "Instalando..." -X 40 -Y 50 -Width 600
    $content.Controls.Add($lblTitle)
    
    $lblSubtitle = New-ModernLabel -Text "Por favor espere mientras se instala la aplicacion" -X 40 -Y 95 -Width 600 -Height 25 -FontSize 12 -IsBold $false -IsPrimary $false
    $content.Controls.Add($lblSubtitle)
    
    # Card de progreso
    $cardPanel = New-ModernPanel -X 40 -Y 150 -Width 600 -Height 200
    $content.Controls.Add($cardPanel)
    
    $lblStatus = New-ModernLabel -Text "Preparando instalacion..." -X 30 -Y 30 -Width 540 -Height 25 -FontSize 10 -IsPrimary $true
    $cardPanel.Controls.Add($lblStatus)
    
    $progressBar = New-ModernProgressBar -X 30 -Y 70 -Width 540 -Height 10
    $cardPanel.Controls.Add($progressBar)
    
    $lblDetails = New-ModernLabel -Text "Iniciando..." -X 30 -Y 95 -Width 540 -Height 80 -FontSize 9 -IsPrimary $false
    $cardPanel.Controls.Add($lblDetails)
    
    # Boton Finalizar (inicialmente oculto)
    $btnFinish = New-ModernButton -Text "Finalizar" -X 500 -Y 500 -Width 140 -Height 44 -IsPrimary $true -OnClick ({
        if ($global:Config.InstallSucceeded) {
            Show-FinishPage -form $form
        }
        else {
            $form.Close()
        }
    }.GetNewClosure())
    $btnFinish.Visible = $false
    $content.Controls.Add($btnFinish)
    
    $form.Controls.Add($content)
    $form.Refresh()
    
    # PROCESO DE INSTALACION REAL X64
    
    $steps = @(
        @{Progress=15; Status="Verificando build y archivos..."; Details="Validando version y hashes SHA-256 del payload..."; Action={
            if (-not (Test-Path -LiteralPath $global:Config.SourcePath -PathType Container)) {
                throw "No se encontro el payload de instalacion en $($global:Config.SourcePath)."
            }
            Assert-PayloadManifest
        }},
        @{Progress=30; Status="Preparando actualizacion..."; Details="Detectando version instalada, cerrando Tienda y protegiendo la base de datos..."; Action={
            $installedVersion = Get-InstalledVersion
            Write-InstallerLog -Level "INFO" -Message "Installed version: $installedVersion"
            Write-InstallerLog -Level "INFO" -Message "New version: $($global:Config.Version)"
            Write-InstallerLog -Level "INFO" -Message "Installation directory: $($global:Config.InstallPath)"
            Stop-InstalledTienda
            Protect-ApplicationDatabase
        }},
        @{Progress=65; Status="Reemplazando archivos de la aplicacion..."; Details="Instalando EXE, DLL, runtime Flutter y recursos; retirando archivos obsoletos..."; Action={
            Install-ApplicationPayload
        }},
        @{Progress=85; Status="Actualizando accesos directos..."; Details="Configurando escritorio y menu de inicio..."; Action={
            $WshShell = New-Object -ComObject WScript.Shell
            $exePath = Join-Path $global:Config.InstallPath "tienda.exe"
            $shortcutIconPath = $exePath
            $installedIconPath = Join-Path $global:Config.InstallPath "app_icon.ico"
            if (Test-Path -LiteralPath $installedIconPath) {
                $shortcutIconPath = $installedIconPath
            }

            if ($global:Config.CreateDesktopShortcut) {
                $currentProfile = [Environment]::GetFolderPath("UserProfile")
                $desktopPath = if ([string]::Equals($global:Config.UserProfilePath, $currentProfile, [System.StringComparison]::OrdinalIgnoreCase)) {
                    [Environment]::GetFolderPath("Desktop")
                }
                else {
                    Join-Path $global:Config.UserProfilePath "Desktop"
                }
                $shortcutPath = Join-Path $desktopPath "Tienda.lnk"
                $shortcut = $WshShell.CreateShortcut($shortcutPath)
                $shortcut.TargetPath = $exePath
                $shortcut.WorkingDirectory = $global:Config.InstallPath
                $shortcut.Description = "Tienda - Sistema de Gestion"
                $shortcut.IconLocation = $shortcutIconPath
                $shortcut.Save()
            }

            if ($global:Config.CreateStartMenuShortcut) {
                $currentProfile = [Environment]::GetFolderPath("UserProfile")
                $startMenuPath = if ([string]::Equals($global:Config.UserProfilePath, $currentProfile, [System.StringComparison]::OrdinalIgnoreCase)) {
                    [Environment]::GetFolderPath("Programs")
                }
                else {
                    Join-Path $global:Config.ApplicationDataPath "Microsoft\Windows\Start Menu\Programs"
                }
                $appFolder = Join-Path $startMenuPath "Tienda"
                if (-not (Test-Path -LiteralPath $appFolder)) {
                    New-Item -Path $appFolder -ItemType Directory -Force | Out-Null
                }
                $shortcutPath = Join-Path $appFolder "Tienda.lnk"
                $shortcut = $WshShell.CreateShortcut($shortcutPath)
                $shortcut.TargetPath = $exePath
                $shortcut.WorkingDirectory = $global:Config.InstallPath
                $shortcut.Description = "Tienda - Sistema de Gestion"
                $shortcut.IconLocation = $shortcutIconPath
                $shortcut.Save()
            }
        }},
        @{Progress=100; Status="Actualizacion completada exitosamente!"; Details="Tienda v$($global:Config.Version) esta listo para usar."; Action={}}
    )
    
    try {
        foreach ($currentStep in $steps) {
            $progressBar.Value = [Math]::Max(0, [Math]::Min(100, $currentStep.Progress))
            $lblStatus.Text = $currentStep.Status
            $lblDetails.Text = $currentStep.Details
            $form.Refresh()
            [System.Windows.Forms.Application]::DoEvents()

            if ($currentStep.Action) {
                & $currentStep.Action
            }

            [System.Windows.Forms.Application]::DoEvents()
        }

        $global:Config.InstallSucceeded = $true
        $progressBar.Value = 100
        $lblStatus.Text = "Actualizacion completada exitosamente!"
        $lblStatus.ForeColor = $global:Colors.Success
        $lblDetails.Text = "Tienda esta listo para usar."
        Update-SidebarStep -form $form -currentStep 5
        $btnFinish.Visible = $true
    }
    catch {
        $errorMessage = $_.Exception.Message
        $global:Config.InstallSucceeded = $false
        Write-InstallerLog -Level "ERROR" -Message $errorMessage
        $lblStatus.Text = "ERROR EN LA INSTALACION"
        $lblStatus.ForeColor = [System.Drawing.Color]::FromArgb(255, 82, 82)
        $lblDetails.Text = "Error: $errorMessage`n`nPor favor, verifique que:`n1. Los archivos de origen existen en build\windows\x64\runner\Release`n2. Tiene permisos de escritura en $($global:Config.InstallPath)`n3. No hay otra instancia en ejecucion"

        [System.Windows.Forms.MessageBox]::Show(
            "Error durante la instalacion: $errorMessage",
            "Error de Instalacion",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        )

        $btnFinish.Text = "Cerrar"
        $btnFinish.Visible = $true
    }
}

# ============================================================================
# PAGINA 5: FINALIZACION
# ============================================================================

function Show-FinishPage {
    param($form)
    
    $global:Config.CurrentStep = 5
    Update-SidebarStep -form $form -currentStep 5
    
    $content = New-ContentPanel -form $form
    
    # Header con icono de exito
    $lblIcon = New-Object System.Windows.Forms.Label
    $lblIcon.Text = "[OK]"
    $lblIcon.Location = New-Object System.Drawing.Point(40, 40)
    $lblIcon.Size = New-Object System.Drawing.Size(80, 80)
    $lblIcon.Font = New-Object System.Drawing.Font("Segoe UI", 32, [System.Drawing.FontStyle]::Bold)
    $lblIcon.ForeColor = $global:Colors.Success
    $lblIcon.BackColor = [System.Drawing.Color]::Transparent
    $lblIcon.TextAlign = 'MiddleCenter'
    $content.Controls.Add($lblIcon)
    
    $lblTitle = New-SectionTitle -Text "Instalacion Completada!" -X 140 -Y 60 -Width 500
    $content.Controls.Add($lblTitle)
    
    $lblSubtitle = New-ModernLabel -Text "Tienda esta listo para usar" -X 140 -Y 105 -Width 500 -Height 25 -FontSize 12 -IsBold $false -IsPrimary $false
    $content.Controls.Add($lblSubtitle)
    
    # Card de informacion
    $cardPanel = New-ModernPanel -X 40 -Y 180 -Width 600 -Height 180
    $content.Controls.Add($cardPanel)
    
    $lblInfo = New-ModernLabel -Text "La aplicacion se ha instalado exitosamente en:" -X 30 -Y 25 -Width 540 -Height 30 -FontSize 11 -IsPrimary $true
    $cardPanel.Controls.Add($lblInfo)
    
    $lblPath = New-ModernLabel -Text $global:Config.InstallPath -X 30 -Y 55 -Width 540 -Height 30 -FontSize 9 -IsBold $true -IsPrimary $false
    $lblPath.ForeColor = $global:Colors.AccentOrange
    $cardPanel.Controls.Add($lblPath)
    
    $lblNextSteps = New-ModernLabel -Text "Proximos pasos:" -X 30 -Y 95 -Width 540 -Height 25 -FontSize 10 -IsBold $true -IsPrimary $true
    $cardPanel.Controls.Add($lblNextSteps)
    
    $lblSteps = New-ModernLabel -Text "* Ejecute la aplicacion desde el acceso directo`n* Configure sus preferencias iniciales`n* Explore todas las funcionalidades disponibles" -X 30 -Y 125 -Width 540 -Height 60 -FontSize 9 -IsPrimary $false
    $cardPanel.Controls.Add($lblSteps)
    
    # Checkbox para ejecutar ahora
    $chkLaunch = New-ModernCheckBox -Text "Ejecutar Tienda ahora" -X 40 -Y 390 -Width 600 -Checked $true
    $content.Controls.Add($chkLaunch)
    
    # Botones
    $btnFinish = New-ModernButton -Text "Finalizar" -X 500 -Y 500 -Width 140 -Height 44 -IsPrimary $true -OnClick ({
        if ($chkLaunch.Checked) {
            try {
                $exePath = Join-Path $global:Config.InstallPath "tienda.exe"
                if (Test-Path $exePath) {
                    Start-Process -FilePath $exePath -WorkingDirectory $global:Config.InstallPath
                }
            } catch {
                [System.Windows.Forms.MessageBox]::Show(
                    "No se pudo ejecutar la aplicacion: $($_.Exception.Message)",
                    "Error",
                    [System.Windows.Forms.MessageBoxButtons]::OK,
                    [System.Windows.Forms.MessageBoxIcon]::Warning
                )
            }
        }
        $form.Close()
    }.GetNewClosure())
    $content.Controls.Add($btnFinish)
    
    $form.Controls.Add($content)
}

# ============================================================================
# PUNTO DE ENTRADA PRINCIPAL
# ============================================================================

try {
    Ensure-InstallerElevation
    $script:InstallerLogPath = Join-Path (Join-Path $env:ProgramData "Tienda") "installer.log"
    Write-InstallerLog -Level "INFO" -Message "Starting Tienda installer"
    Write-InstallerLog -Level "INFO" -Message "New version: $($global:Config.Version)"
    Write-InstallerLog -Level "INFO" -Message "Installation directory: $($global:Config.InstallPath)"
    $mainForm = New-ModernMainWindow
    Show-WelcomePage -form $mainForm
    [void]$mainForm.ShowDialog()
}
catch {
    Write-InstallerLog -Level "ERROR" -Message $_.Exception.Message
    [System.Windows.Forms.MessageBox]::Show(
        "Error al iniciar el instalador: $($_.Exception.Message)",
        "Error",
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Error
    )
}
finally {
    if ($mainForm) {
        $mainForm.Dispose()
    }
}