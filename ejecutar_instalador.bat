@echo off
:: ============================================================================
:: Lanzador por lotes para el instalador desatendido en Windows 10 y 11
:: Eleva permisos a Administrador y ejecuta PowerShell sin restricciones
:: ============================================================================
title Lanzador de Instalacion Desatendida
cd /d "%~dp0"

:: Comprobación de privilegios de Administrador
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo [!] Solicitando permisos de Administrador...
    powershell.exe -NoProfile -Command "Start-Process '%~f0' -Verb RunAs"
    exit /b
)

echo [+] Comprobando la politica de ejecucion de PowerShell...
powershell.exe -NoProfile -Command "if ((Get-ExecutionPolicy -Scope MachinePolicy) -eq 'Undefined' -and (Get-ExecutionPolicy -Scope UserPolicy) -eq 'Undefined') { foreach ($s in 'LocalMachine','CurrentUser') { if ((Get-ExecutionPolicy -Scope $s) -ne 'Unrestricted') { Set-ExecutionPolicy -Scope $s -ExecutionPolicy Unrestricted -Force -ErrorAction SilentlyContinue } } }"

echo [+] Iniciando instalador desatendido en PowerShell...
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0instalar_programas.ps1"
if %errorlevel% neq 0 (
    echo.
    echo [-] El instalador finalizo con codigo de error: %errorlevel%
    pause
)
exit /b
