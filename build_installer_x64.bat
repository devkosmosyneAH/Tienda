@echo off
chcp 65001 >nul
cls
color 0A

echo ╔════════════════════════════════════════════════════════════════╗
echo ║       COMPILADOR DE INSTALADOR PREMIUM x64                     ║
echo ║              tienda v2.0.0                            ║
echo ╚════════════════════════════════════════════════════════════════╝
echo.

:: ========== VERIFICAR EJECUTABLE ==========
echo [1/5] Verificando ejecutable x64...
if not exist "build\windows\x64\runner\Release\tienda.exe" (
    echo ❌ ERROR: No se encontró el ejecutable x64
    echo Por favor, compila primero: flutter build windows --release
    echo.
    pause
    exit /b 1
)
echo ✓ Ejecutable x64 encontrado
echo.

:: ========== VERIFICAR ASSETS PREMIUM ==========
echo [2/5] Verificando assets del instalador premium...
set ASSETS_WARNING=0

if not exist "installer_assets" (
    echo ⚠ Creando carpeta installer_assets...
    mkdir installer_assets
)

if not exist "installer_assets\app_icon.ico" (
    echo ⚠ ADVERTENCIA: Falta app_icon.ico (icono de la app)
    set ASSETS_WARNING=1
)

if not exist "installer_assets\wizard_image.bmp" (
    echo ⚠ ADVERTENCIA: Falta wizard_image.bmp (sidebar 164x314px)
    set ASSETS_WARNING=1
)

if not exist "installer_assets\wizard_small_image.bmp" (
    echo ⚠ ADVERTENCIA: Falta wizard_small_image.bmp (logo 55x58px)
    set ASSETS_WARNING=1
)

if %ASSETS_WARNING%==1 (
    echo.
    echo ════════════════════════════════════════════════════════════════
    echo   ⚠ ADVERTENCIA: Faltan algunos assets del diseño premium
    echo ════════════════════════════════════════════════════════════════
    echo.
    echo El instalador funcionará pero puede no verse completamente premium.
    echo Para el diseño completo, consulta: INSTALADOR_PREMIUM_GUIA.md
    echo.
    echo ⏱ Continuando automáticamente en 3 segundos...
    timeout /t 3 /nobreak >nul
    echo.
)
echo ✓ Verificación de assets completada
echo.

:: ========== CREAR DIRECTORIO DE SALIDA ==========
if not exist "installer_output" mkdir installer_output

:: ========== BUSCAR INNO SETUP ==========
echo [3/5] Buscando Inno Setup...
set INNO_SETUP=""
if exist "C:\Program Files (x86)\Inno Setup 6\ISCC.exe" (
    set INNO_SETUP="C:\Program Files (x86)\Inno Setup 6\ISCC.exe"
) else if exist "C:\Program Files\Inno Setup 6\ISCC.exe" (
    set INNO_SETUP="C:\Program Files\Inno Setup 6\ISCC.exe"
) else if exist "C:\Program Files (x86)\Inno Setup 5\ISCC.exe" (
    set INNO_SETUP="C:\Program Files (x86)\Inno Setup 5\ISCC.exe"
) else if exist "C:\Program Files\Inno Setup 5\ISCC.exe" (
    set INNO_SETUP="C:\Program Files\Inno Setup 5\ISCC.exe"
)

if %INNO_SETUP%=="" (
    echo ❌ ERROR: Inno Setup no está instalado
    echo.
    echo Descárgalo desde: https://jrsoftware.org/isdl.php
    echo.
    pause
    exit /b 1
)

echo ✓ Inno Setup encontrado
echo.

:: ========== VERIFICAR SCRIPT PREMIUM ==========
echo [4/5] Verificando script premium...
if not exist "tienda_Premium_Setup.iss" (
    echo ❌ ERROR: No se encuentra tienda_Premium_Setup.iss
    echo.
    pause
    exit /b 1
)
echo ✓ Script premium encontrado
echo.

:: ========== COMPILAR INSTALADOR PREMIUM ==========
echo [5/5] Compilando instalador PREMIUM x64...
echo Esto puede tardar unos minutos...
echo.

%INNO_SETUP% "tienda_Premium_Setup.iss"

if %ERRORLEVEL% EQU 0 (
    cls
    echo.
    echo ╔════════════════════════════════════════════════════════════════╗
    echo ║            ✓ INSTALADOR PREMIUM COMPILADO ✓                   ║
    echo ╚════════════════════════════════════════════════════════════════╝
    echo.
    echo El instalador premium x64 se ha creado correctamente:
    echo.
    echo 📁 Ubicación:
    echo    installer_output\tienda_Setup_v2.0.0.exe
    echo.
    echo 📊 Información:
    if exist "installer_output\tienda_Setup_v2.0.0.exe" (
        for %%I in ("installer_output\tienda_Setup_v2.0.0.exe") do (
            echo    Tamaño: %%~zI bytes
            echo    Fecha: %%~tI
        )
    )
    echo.
    echo ✨ CARACTERÍSTICAS PREMIUM:
    echo    ✓ Diseño oscuro profesional
    echo    ✓ Sidebar elegante con branding
    echo    ✓ Colores premium personalizados
    echo    ✓ Compatible Windows 10/11
    echo    ✓ Instalación rápida y moderna
    echo.
    echo ════════════════════════════════════════════════════════════════
    echo.
    echo ¿Deseas ejecutar el instalador ahora? ^(S/N^)
    choice /C SN /N /M "Presiona S para ejecutar, N para salir: "
    if errorlevel 2 (
        echo.
        echo Puedes ejecutar el instalador desde:
        echo installer_output\tienda_Setup_v2.0.0.exe
        echo.
        pause
        exit /b 0
    )
    echo.
    echo Ejecutando instalador premium...
    start "" "installer_output\tienda_Setup_v2.0.0.exe"
) else (
    echo.
    echo ╔════════════════════════════════════════════════════════════════╗
    echo ║                ❌ ERROR AL COMPILAR                            ║
    echo ╚════════════════════════════════════════════════════════════════╝
    echo.
    echo Posibles causas:
    echo   - Faltan assets requeridos
    echo   - Error en el script .iss
    echo   - Rutas incorrectas
    echo.
    echo Consulta: INSTALADOR_PREMIUM_GUIA.md
)

echo.
pause