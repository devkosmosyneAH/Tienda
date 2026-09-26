@echo off
chcp 65001 >nul
cls
color 0A

echo ╔════════════════════════════════════════════════════════════════╗
echo ║         COMPILADOR DE INSTALADOR PREMIUM                       ║
echo ║              Tienda v2.0.0                            ║
echo ╚════════════════════════════════════════════════════════════════╝
echo.

:: ========== VERIFICAR INNO SETUP ==========
echo [1/6] Verificando Inno Setup...
if not exist "C:\Program Files (x86)\Inno Setup 6\ISCC.exe" (
    echo ❌ ERROR: Inno Setup 6 no está instalado
    echo.
    echo Descárgalo desde: https://jrsoftware.org/isdl.php
    echo.
    pause
    exit /b 1
)
echo ✓ Inno Setup 6 encontrado
echo.

:: ========== VERIFICAR SCRIPT .ISS ==========
echo [2/6] Verificando script del instalador...
if not exist "tienda_Premium_Setup.iss" (
    echo ❌ ERROR: No se encuentra tienda_Premium_Setup.iss
    pause
    exit /b 1
)
echo ✓ Script .iss encontrado
echo.

:: ========== VERIFICAR ASSETS ==========
echo [3/6] Verificando assets del instalador...
set ASSETS_OK=1

if not exist "installer_assets" (
    echo ⚠ Creando carpeta installer_assets...
    mkdir installer_assets
)

if not exist "installer_assets\app_icon.ico" (
    echo ⚠ ADVERTENCIA: Falta app_icon.ico
    echo   Copiando icono temporal desde assets...

    :: Intentar copiar desde assets existentes
    if exist "assets\image\logotienda.png" (
        echo   → Necesitas convertir logotienda.png a .ico manualmente
        echo   → Usa: https://icoconvert.com/
    )
    set ASSETS_OK=0
)

if not exist "installer_assets\wizard_image.bmp" (
    echo ⚠ ADVERTENCIA: Falta wizard_image.bmp ^(164x314 píxeles^)
    set ASSETS_OK=0
)

if not exist "installer_assets\wizard_small_image.bmp" (
    echo ⚠ ADVERTENCIA: Falta wizard_small_image.bmp ^(55x58 píxeles^)
    set ASSETS_OK=0
)

if %ASSETS_OK%==0 (
    echo.
    echo ════════════════════════════════════════════════════════════════
    echo   FALTAN ASSETS REQUERIDOS
    echo ════════════════════════════════════════════════════════════════
    echo.
    echo Necesitas crear los siguientes archivos en installer_assets/:
    echo.
    echo 1. app_icon.ico          - Icono 256x256 multi-resolución
    echo 2. wizard_image.bmp      - Sidebar 164x314 píxeles ^(dark mode^)
    echo 3. wizard_small_image.bmp - Logo pequeño 55x58 píxeles
    echo.
    echo Consulta INSTALADOR_PREMIUM_GUIA.md para más detalles
    echo.
    echo ¿Deseas continuar de todos modos? ^(S/N^)
    choice /C SN /N /M "Presiona S para continuar, N para cancelar: "
    if errorlevel 2 (
        echo.
        echo ❌ Compilación cancelada
        pause
        exit /b 1
    )
    echo.
    echo ⚠ Continuando sin assets completos...
    echo   El instalador puede no verse correctamente.
    echo.
)
echo ✓ Verificación de assets completada
echo.

:: ========== COMPILAR FLUTTER APP ==========
echo [4/6] Compilando aplicación Flutter...
echo   Esto puede tardar varios minutos...
echo.

flutter build windows --release

if errorlevel 1 (
    echo.
    echo ❌ ERROR: Falló la compilación de Flutter
    echo.
    pause
    exit /b 1
)
echo.
echo ✓ Aplicación Flutter compilada exitosamente
echo.

:: ========== VERIFICAR BUILD ==========
echo [5/6] Verificando archivos compilados...

if not exist "build\windows\x64\runner\Release\tienda.exe" (
    echo ❌ ERROR: No se encuentra tienda.exe
    echo   Verifica que la compilación de Flutter fue exitosa
    pause
    exit /b 1
)

if not exist "build\windows\x64\runner\Release\data" (
    echo ❌ ERROR: No se encuentra la carpeta data/
    pause
    exit /b 1
)

echo ✓ Archivos compilados verificados
echo.

:: ========== COMPILAR INSTALADOR ==========
echo [6/6] Compilando instalador con Inno Setup...
echo.

"C:\Program Files (x86)\Inno Setup 6\ISCC.exe" "tienda_Premium_Setup.iss"

if errorlevel 1 (
    echo.
    echo ❌ ERROR: Falló la compilación del instalador
    echo.
    echo Posibles causas:
    echo   - Faltan assets requeridos
    echo   - Error en el script .iss
    echo   - Rutas incorrectas
    echo.
    pause
    exit /b 1
)

:: ========== ÉXITO ==========
cls
echo.
echo ╔════════════════════════════════════════════════════════════════╗
echo ║                 ✓ COMPILACIÓN EXITOSA ✓                       ║
echo ╚════════════════════════════════════════════════════════════════╝
echo.
echo El instalador se ha creado correctamente:
echo.
echo 📁 Ubicación:
echo    installer_output\tienda_Setup_v2.0.0.exe
echo.
echo 📊 Información:
if exist "installer_output\tienda_Premium_Setup.exe" (
    for %%I in ("installer_output\tienda_Premium_Setup.exe") do (
        echo    Tamaño: %%~zI bytes ^(~%%~zI MB^)
        echo    Fecha: %%~tI
    )
)
echo.
echo ════════════════════════════════════════════════════════════════
echo.
echo ¿Deseas ejecutar el instalador ahora? ^(S/N^)
choice /C SN /N /M "Presiona S para ejecutar, N para salir: "
if errorlevel 2 (
    echo.
    echo Puedes ejecutar el instalador manualmente desde:
    echo installer_output\tienda_Premium_Setup.exe
    echo.
    pause
    exit /b 0
)

echo.
echo Ejecutando instalador...
start "" "installer_output\tienda_Premium_Setup.exe"
echo.
pause
exit /b 0