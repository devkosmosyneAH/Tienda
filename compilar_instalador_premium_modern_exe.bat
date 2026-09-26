@echo off
chcp 65001 >nul
setlocal

echo ================================================================
echo COMPILADOR EXE - INSTALADOR PREMIUM MODERN
echo Tienda v2.0.0
echo ================================================================
echo.

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0compilar_instalador_premium_modern_exe.ps1"

if errorlevel 1 (
    echo.
    echo ERROR: No se pudo generar el instalador EXE.
    pause
    exit /b 1
)

echo.
echo Compilacion completada.
pause
exit /b 0