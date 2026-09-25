; ============================================================================
; INSTALADOR PREMIUM - Tienda SAAS
; Diseño Moderno Estilo Discord/VS Code/Notion
; Compatible con Windows 10/11
; ============================================================================

#define AppName "Tienda SAAS"
#define AppVersion "2.0.0"
#define AppPublisher "Tienda SAAS"
#define AppExeName "tienda.exe"
#define AppId "A92AAE7F-C65A-4B2C-8D1E-1F2E3D4C5B6A"

[Setup]
; ============= INFORMACIÓN BÁSICA =============
AppId={{{#AppId}}
AppName={#AppName}
AppVersion={#AppVersion}
AppVerName={#AppName} {#AppVersion}
AppPublisher={#AppPublisher}
AppPublisherURL=https://tienda.com
AppSupportURL=https://tienda.com/soporte
AppUpdatesURL=https://tienda.com/actualizaciones
DefaultDirName={autopf}\Tienda
DefaultGroupName={#AppName}
DisableProgramGroupPage=yes
AllowNoIcons=yes

; ============= ARCHIVOS DE SALIDA =============
OutputDir=installer_output
OutputBaseFilename=tienda_Setup_v{#AppVersion}
SetupIconFile=installer_assets\app_icon.ico
UninstallDisplayIcon={app}\{#AppExeName}

; ============= COMPRESIÓN =============
Compression=lzma2/ultra64
SolidCompression=yes
LZMAUseSeparateProcess=yes
LZMANumBlockThreads=2

; ============= DISEÑO ULTRA MODERNO (PREMIUM DARK UI) =============
WizardStyle=modern
WizardResizable=no
DisableWelcomePage=no

; Colores Premium Dark Theme (#111111, #1E1E1E, #FF8C42, #EAEAEA)
WizardImageBackColor=$111111
SetupLogging=yes

; ============= IMÁGENES PERSONALIZADAS PREMIUM =============
; Sidebar izquierda (164x314 píxeles) - Dark premium branding
WizardImageFile=installer_assets\wizard_image.bmp
WizardImageStretch=no
WizardImageAlphaFormat=none

; Banner superior pequeño (55x58 píxeles) - Minimal logo
WizardSmallImageFile=installer_assets\wizard_small_image.bmp

; ============= REQUISITOS DEL SISTEMA =============
MinVersion=10.0.17763
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible

; ============= PRIVILEGIOS =============
PrivilegesRequired=admin
PrivilegesRequiredOverridesAllowed=dialog

; ============= INFORMACIÓN DE VERSIÓN =============
VersionInfoVersion={#AppVersion}
VersionInfoCompany={#AppPublisher}
VersionInfoDescription=Sistema de Gestión Empresarial
VersionInfoTextVersion={#AppVersion}
VersionInfoProductName={#AppName}
VersionInfoProductVersion={#AppVersion}

[Languages]
Name: "spanish"; MessagesFile: "compiler:Languages\Spanish.isl"

[CustomMessages]
spanish.WelcomeLabel1=Tienda SAAS
spanish.WelcomeLabel2=Sistema de Gestión Empresarial Premium%n%nModerno • Rápido • Profesional
spanish.FinishedHeadingLabel=Instalación completada exitosamente
spanish.FinishedLabelNoIcons=Tienda SAAS está listo para usar.
spanish.FinishedLabel=Tienda SAAS está listo para usar.%n%nPuedes iniciarlo desde el menú de inicio o el escritorio.
spanish.ClickFinish=Finalizar
spanish.SelectDirLabel3=El instalador necesita permisos de administrador para instalar en esta ubicación.
spanish.SelectDirBrowseLabel=Haga clic en Siguiente para continuar con la instalación.
spanish.PreparingDesc=Preparando la instalación de Tienda SAAS...

[Tasks]
Name: "desktopicon"; Description: "Crear icono en el &escritorio"; GroupDescription: "Accesos directos:"; Flags: unchecked
Name: "quicklaunchicon"; Description: "Crear icono en inicio &rápido"; GroupDescription: "Accesos directos:"; Flags: unchecked; OnlyBelowVersion: 0,6.1

[Files]
; ========== EJECUTABLE PRINCIPAL ==========
Source: "build\windows\x64\runner\Release\{#AppExeName}"; DestDir: "{app}"; Flags: ignoreversion

; ========== DLLs REQUERIDAS ==========
Source: "build\windows\x64\runner\Release\*.dll"; DestDir: "{app}"; Flags: ignoreversion

; ========== DATOS Y ASSETS ==========
Source: "build\windows\x64\runner\Release\data\*"; DestDir: "{app}\data"; Flags: ignoreversion recursesubdirs createallsubdirs

; ========== ASSETS DEL INSTALADOR (OPCIONAL) ==========
; Source: "installer_assets\LEEME.txt"; DestDir: "{app}"; Flags: ignoreversion isreadme

[Icons]
; Icono en el menú de inicio
Name: "{autoprograms}\{#AppName}"; Filename: "{app}\{#AppExeName}"; IconFilename: "{app}\{#AppExeName}"

; Icono en el escritorio
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\{#AppExeName}"; IconFilename: "{app}\{#AppExeName}"; Tasks: desktopicon

; Icono en inicio rápido
Name: "{userappdata}\Microsoft\Internet Explorer\Quick Launch\{#AppName}"; Filename: "{app}\{#AppExeName}"; Tasks: quicklaunchicon

; Desinstalador
Name: "{autoprograms}\Desinstalar {#AppName}"; Filename: "{uninstallexe}"

[Run]
; Ejecutar la aplicación al finalizar (opcional)
Filename: "{app}\{#AppExeName}"; Description: "Ejecutar {#AppName}"; Flags: nowait postinstall skipifsilent

[Registry]
; Registrar la aplicación en el registro de Windows
Root: HKCU; Subkey: "Software\{#AppPublisher}\{#AppName}"; ValueType: string; ValueName: "InstallPath"; ValueData: "{app}"; Flags: uninsdeletekey
Root: HKCU; Subkey: "Software\{#AppPublisher}\{#AppName}"; ValueType: string; ValueName: "Version"; ValueData: "{#AppVersion}"
Root: HKCU; Subkey: "Software\{#AppPublisher}\{#AppName}"; ValueType: string; ValueName: "InstallDate"; ValueData: "{code:GetInstallDate}"

[UninstallDelete]
; Limpiar archivos generados por la aplicación al desinstalar
Type: filesandordirs; Name: "{app}\logs"
Type: filesandordirs; Name: "{app}\cache"
Type: filesandordirs; Name: "{app}\temp"
Type: files; Name: "{app}\*.log"

[Code]
// ============================================================================
// CÓDIGO PASCAL PREMIUM - UI ULTRA MODERNA
// Inspirado en: VS Code, Discord, Notion, Linear
// ============================================================================

// ========== FUNCIÓN: OBTENER FECHA DE INSTALACIÓN ==========
function GetInstallDate(Param: String): String;
begin
  Result := GetDateTimeString('yyyy/mm/dd hh:nn:ss', '-', ':');
end;

// ========== FUNCIÓN: VERIFICAR SI ES ACTUALIZACIÓN ==========
function IsUpgrade(): Boolean;
var
  UninstallKey: String;
  InstallPath: String;
begin
  Result := False;
  UninstallKey := 'Software\Microsoft\Windows\CurrentVersion\Uninstall\{#AppId}_is1';
  
  if RegQueryStringValue(HKLM, UninstallKey, 'InstallLocation', InstallPath) then
    Result := True
  else if RegQueryStringValue(HKCU, UninstallKey, 'InstallLocation', InstallPath) then
    Result := True;
end;

// ========== FUNCIÓN: DESINSTALAR VERSIÓN ANTERIOR ==========
function UnInstallOldVersion(): Integer;
var
  UninstallString: String;
  ResultCode: Integer;
begin
  Result := 0;
  
  if IsUpgrade() then
  begin
    if MsgBox('Se detectó una instalación anterior. ¿Desinstalar antes de continuar?', 
              mbConfirmation, MB_YESNO) = IDYES then
    begin
      if RegQueryStringValue(HKCU, 'Software\Microsoft\Windows\CurrentVersion\Uninstall\{#AppId}_is1', 
                             'UninstallString', UninstallString) then
      begin
        UninstallString := RemoveQuotes(UninstallString);
        if Exec(UninstallString, '/SILENT /NORESTART /SUPPRESSMSGBOXES', '', SW_HIDE, 
                ewWaitUntilTerminated, ResultCode) then
          Result := ResultCode;
      end;
    end;
  end;
end;

// ========== PERSONALIZACIÓN ULTRA MODERNA DE UI ==========
procedure ModernizeUI();
var
  I: Integer;
begin
  // ========== TIPOGRAFÍA PREMIUM ==========
  // Títulos grandes y modernos (estilo VS Code/Discord)
  WizardForm.WelcomeLabel1.Font.Name := 'Segoe UI';
  WizardForm.WelcomeLabel1.Font.Size := 20;
  WizardForm.WelcomeLabel1.Font.Style := [fsBold];
  
  WizardForm.WelcomeLabel2.Font.Name := 'Segoe UI';
  WizardForm.WelcomeLabel2.Font.Size := 10;
  WizardForm.WelcomeLabel2.Font.Style := [];
  
  WizardForm.FinishedHeadingLabel.Font.Name := 'Segoe UI';
  WizardForm.FinishedHeadingLabel.Font.Size := 20;
  WizardForm.FinishedHeadingLabel.Font.Style := [fsBold];
  
  WizardForm.FinishedLabel.Font.Name := 'Segoe UI';
  WizardForm.FinishedLabel.Font.Size := 10;
  
  // ========== BOTONES MODERNOS ==========
  // Botones más grandes y con tipografía premium
  WizardForm.NextButton.Font.Name := 'Segoe UI Semibold';
  WizardForm.NextButton.Font.Size := 10;
  WizardForm.NextButton.Height := 36;
  WizardForm.NextButton.Width := 100;
  
  WizardForm.CancelButton.Font.Name := 'Segoe UI';
  WizardForm.CancelButton.Font.Size := 9;
  WizardForm.CancelButton.Height := 36;
  WizardForm.CancelButton.Width := 80;
  
  WizardForm.BackButton.Font.Name := 'Segoe UI';
  WizardForm.BackButton.Font.Size := 9;
  WizardForm.BackButton.Height := 36;
  WizardForm.BackButton.Width := 80;
  
  // ========== LABELS Y TEXTOS ==========
  // Aplicar fuente moderna a todos los labels
  for I := 0 to WizardForm.ComponentCount - 1 do
  begin
    if WizardForm.Components[I] is TLabel then
    begin
      with TLabel(WizardForm.Components[I]) do
      begin
        Font.Name := 'Segoe UI';
        if Font.Size < 9 then Font.Size := 9;
      end;
    end;
  end;
  
  // ========== PÁGINA DE DIRECTORIO ==========
  if Assigned(WizardForm.SelectDirLabel) then
  begin
    WizardForm.SelectDirLabel.Font.Name := 'Segoe UI';
    WizardForm.SelectDirLabel.Font.Size := 10;
  end;
  
  if Assigned(WizardForm.SelectDirBrowseLabel) then
  begin
    WizardForm.SelectDirBrowseLabel.Font.Name := 'Segoe UI';
    WizardForm.SelectDirBrowseLabel.Font.Size := 9;
  end;
  
  // ========== CAMPOS DE TEXTO ==========
  if Assigned(WizardForm.DirEdit) then
  begin
    WizardForm.DirEdit.Font.Name := 'Segoe UI';
    WizardForm.DirEdit.Font.Size := 9;
  end;
end;

// ========== INICIALIZACIÓN DEL WIZARD ==========
procedure InitializeWizard();
begin
  // Aplicar tema oscuro ultra moderno
  ModernizeUI();
end;

// ========== FUNCIÓN: ANTES DE INSTALAR ==========
function InitializeSetup(): Boolean;
begin
  Result := True;
  
  // Desinstalar versión anterior si existe
  UnInstallOldVersion();
end;

// ========== FUNCIÓN: VERIFICAR REQUISITOS ==========
function CheckRequirements(): Boolean;
var
  Version: TWindowsVersion;
begin
  Result := True;
  GetWindowsVersionEx(Version);
  
  // Verificar Windows 10 versión 1809 o superior
  if (Version.Major < 10) or 
     ((Version.Major = 10) and (Version.Build < 17763)) then
  begin
    MsgBox('Este instalador requiere Windows 10 versión 1809 o superior, o Windows 11.', 
           mbError, MB_OK);
    Result := False;
  end;
end;

// ========== FUNCIÓN: BOTÓN SIGUIENTE ==========
function NextButtonClick(CurPageID: Integer): Boolean;
begin
  Result := True;
  
  case CurPageID of
    wpWelcome:
    begin
      // Verificar requisitos en la pantalla de bienvenida
      Result := CheckRequirements();
    end;
  end;
end;

// ========== MENSAJE DE PROGRESO PERSONALIZADO ==========
procedure CurStepChanged(CurStep: TSetupStep);
begin
  case CurStep of
    ssInstall:
      WizardForm.StatusLabel.Caption := 'Instalando Tienda SAAS...';
    ssPostInstall:
      WizardForm.StatusLabel.Caption := 'Finalizando instalación...';
  end;
end;

// ============================================================================
// FIN DEL CÓDIGO PASCAL PREMIUM
// ============================================================================