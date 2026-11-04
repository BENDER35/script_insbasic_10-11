<#
.SYNOPSIS
    Script de instalación desatendida para Windows 10 y 11.
    Instala:
      1. Google Chrome
      2. 7-Zip
      3. Adobe Acrobat Reader (64 bits)
      4. VLC Media Player
      5. K-Lite Codec Pack
      6. Topgrade
      7. Zoom
      8. Microsoft Teams
      9. AnyDesk
     10. RustDesk
     11. scrcpy
     12. aTube Catcher
     13. Microsoft Office LTSC 2024 (Español, 64 bits)

.NOTES
    Requiere ejecución con privilegios de Administrador y conexión a Internet.
#>

# Forzar codificación UTF-8 en consola
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

# Configurar protocolos TLS modernos y acelerar descargas en PowerShell 5.1
# Tls13 solo existe en .NET Framework 4.8+; si no está disponible, se usa Tls12.
try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 -bor [Net.SecurityProtocolType]::Tls13
} catch {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
}
$ProgressPreference = 'SilentlyContinue'

# ==========================================
# 0. Verificación y elevación a Administrador
# ==========================================
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "[!] El script requiere privilegios de Administrador. Solicitando elevación..." -ForegroundColor Yellow
    Start-Process powershell.exe -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "`"$PSCommandPath`"") -Verb RunAs
    exit
}

Clear-Host
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host " INSTALADOR DESATENDIDO - WINDOWS 10 / WINDOWS 11        " -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host ""

# ==========================================
# 0.1. Verificación de la política de ejecución de PowerShell
# ==========================================
# Se comprueba si la política está impuesta por directiva de grupo (GPO).
# Si no lo está, se ajusta a 'Unrestricted' para permitir cualquier script .ps1.
$gpoMachine = Get-ExecutionPolicy -Scope MachinePolicy
$gpoUser    = Get-ExecutionPolicy -Scope UserPolicy

if ($gpoMachine -ne 'Undefined' -or $gpoUser -ne 'Undefined') {
    Write-Host "[!] La política de ejecución está gestionada por directiva de grupo (GPO):" -ForegroundColor Yellow
    Write-Host "    MachinePolicy = $gpoMachine | UserPolicy = $gpoUser" -ForegroundColor Yellow
    Write-Host "    No se puede modificar desde este script. Se continuará usando -ExecutionPolicy Bypass." -ForegroundColor Yellow
} else {
    $policyChanged = $false
    foreach ($scope in @('LocalMachine', 'CurrentUser')) {
        $currentPolicy = Get-ExecutionPolicy -Scope $scope
        if ($currentPolicy -ne 'Unrestricted') {
            try {
                Set-ExecutionPolicy -Scope $scope -ExecutionPolicy Unrestricted -Force -ErrorAction Stop
                Write-Host "    [OK] Política de ejecución ($scope): $currentPolicy -> Unrestricted." -ForegroundColor Green
                $policyChanged = $true
            } catch {
                Write-Host "    [!] No se pudo cambiar la política en el ámbito $scope : $_" -ForegroundColor Red
                Write-Host "    [i] El script continúa ejecutándose gracias a -ExecutionPolicy Bypass." -ForegroundColor Yellow
            }
        }
    }
    if (-not $policyChanged) {
        Write-Host "[OK] La política de ejecución ya es 'Unrestricted'." -ForegroundColor Green
    }
}

# Directorio temporal de trabajo
$WorkDir = "$env:TEMP\InstaladorDesatendido"
if (-not (Test-Path $WorkDir)) {
    New-Item -ItemType Directory -Path $WorkDir -Force | Out-Null
}

# ==========================================
# 1. Comprobar / Instalar aplicaciones con WinGet
# ==========================================
# Función robusta para localizar winget.exe incluso en sesiones elevadas
function Get-WinGetExecutable {
    # 1. Comprobar si está en el PATH
    $cmd = Get-Command "winget" -ErrorAction SilentlyContinue
    if ($cmd) { return "winget" }

    # 2. Comprobar en Microsoft.DesktopAppInstaller (Program Files)
    $appInstaller = Get-ChildItem "$env:ProgramFiles\WindowsApps\Microsoft.DesktopAppInstaller_*_x64__8wekyb3d8bbwe\winget.exe" -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($appInstaller -and (Test-Path $appInstaller.FullName)) {
        return $appInstaller.FullName
    }

    # 3. Comprobar mediante el paquete Appx instalado en la máquina
    $pkg = Get-AppxPackage -AllUsers -Name "Microsoft.DesktopAppInstaller" -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($pkg -and $pkg.InstallLocation) {
        $candidate = Join-Path $pkg.InstallLocation "winget.exe"
        if (Test-Path $candidate) {
            return $candidate
        }
    }

    # 4. Comprobar en AppData Local del usuario
    $localAppPath = Resolve-Path "$env:LOCALAPPDATA\Microsoft\WindowsApps\winget.exe" -ErrorAction SilentlyContinue
    if ($localAppPath -and (Test-Path $localAppPath.Path)) {
        return $localAppPath.Path
    }

    return $null
}

# Comprueba si un paquete de WinGet ya está instalado.
# Para paquetes MSIX (como la nueva app de Teams) se comprueba además el paquete Appx.
function Test-WingetAppInstalled {
    param(
        [string]$WingetExe,
        [string]$Id,
        [string]$AppxName
    )

    if ($AppxName) {
        $appx = Get-AppxPackage -Name $AppxName -ErrorAction SilentlyContinue
        if ($appx) { return $true }
    }

    if (-not $WingetExe) { return $false }

    try {
        $output = (& $WingetExe list --id $Id -e --accept-source-agreements 2>$null | Out-String)
        if ($LASTEXITCODE -ne 0) { return $false }
        # Algunas versiones de winget devuelven 0 aunque no encuentren el paquete.
        if ($output -match '(?i)No\s+(installed\s+package|se\s+encontr)') { return $false }
        return $true
    } catch {
        return $false
    }
}

# Comprueba si hay software instalado cuyo nombre coincida con un patrón,
# consultando las tres ubicaciones habituales del registro de Windows.
function Test-SoftwareInstalled {
    param([string]$NamePattern)

    $uninstallRoots = @(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*'
    )

    foreach ($root in $uninstallRoots) {
        $found = Get-ItemProperty -Path $root -ErrorAction SilentlyContinue |
                 Where-Object { $_.DisplayName -and $_.DisplayName -match $NamePattern } |
                 Select-Object -First 1
        if ($found) { return $true }
    }
    return $false
}

# Comprueba si Office 2024 (ProPlus Volume) ya está instalado mediante Click-to-Run.
function Test-Office2024Installed {
    $configKey = 'HKLM:\SOFTWARE\Microsoft\Office\ClickToRun\Configuration'
    if (Test-Path $configKey) {
        $config = Get-ItemProperty -Path $configKey -ErrorAction SilentlyContinue
        if ($config -and $config.ProductReleaseIds -match 'ProPlus2024Volume') {
            return $true
        }
    }
    return $false
}

$wingetCmd = Get-WinGetExecutable

$wingetApps = @(
    @{ Name = "Google Chrome";        Id = "Google.Chrome" },
    @{ Name = "7-Zip";                Id = "7zip.7zip" },
    @{ Name = "Adobe Acrobat Reader"; Id = "Adobe.Acrobat.Reader.64-bit" },
    @{ Name = "VLC Media Player";     Id = "VideoLAN.VLC" },
    @{ Name = "K-Lite Codec Pack";    Id = "CodecGuide.K-LiteCodecPack.Standard" },
    @{ Name = "Topgrade";             Id = "topgrade-rs.topgrade" },
    @{ Name = "Zoom";                 Id = "Zoom.Zoom" },
    @{ Name = "Microsoft Teams";      Id = "Microsoft.Teams"; Appx = "MSTeams" },
    @{ Name = "AnyDesk";              Id = "AnyDeskSoftwareGmbH.AnyDesk" },
    @{ Name = "RustDesk";             Id = "RustDesk.RustDesk" },
    @{ Name = "scrcpy";               Id = "Genymobile.scrcpy" }
)

if ($wingetCmd) {
    Write-Host "[+] Instalando aplicaciones base mediante WinGet..." -ForegroundColor Green
    foreach ($app in $wingetApps) {
        if (Test-WingetAppInstalled -WingetExe $wingetCmd -Id $app.Id -AppxName $app.Appx) {
            Write-Host "    [=] $($app.Name) ya está instalado. Se omite." -ForegroundColor DarkGray
            continue
        }
        Write-Host "    -> Instalando $($app.Name)..." -ForegroundColor White
        & $wingetCmd install --id $app.Id -e --silent --accept-source-agreements --accept-package-agreements --force
        if ($LASTEXITCODE -eq 0) {
            Write-Host "       [OK] $($app.Name) instalado o ya actualizado." -ForegroundColor Green
        } else {
            Write-Host "       [i] Código de retorno: $LASTEXITCODE para $($app.Name)." -ForegroundColor Yellow
        }
    }
} else {
    Write-Host "[-] WinGet no está disponible en este sistema." -ForegroundColor Red
    Write-Host "    Asegúrate de actualizar 'Instalador de la aplicación' desde Microsoft Store." -ForegroundColor Yellow
}

# ==========================================
# 2. Instalación desatendida de aTube Catcher
# ==========================================
Write-Host ""
if (Test-SoftwareInstalled -NamePattern 'aTube\s*Catcher') {
    Write-Host "[=] aTube Catcher ya está instalado. Se omite." -ForegroundColor DarkGray
} else {
    Write-Host "[+] Descargando e instalando aTube Catcher..." -ForegroundColor Green
    $aTubeInstaller = "$WorkDir\aTubeCatcher.exe"
    $aTubeUrls = @(
        "https://opera.dsnetwb.com/files/aTube-Catcher-Setup-26.8.18-x64.exe",
        "https://dt60lys1dmwha.cloudfront.net/xXKbbYh/vd1g.exe"
    )

    $downloadSuccess = $false
    foreach ($url in $aTubeUrls) {
        try {
            Write-Host "    -> Intentando descarga desde servidor oficial..." -ForegroundColor White
            Invoke-WebRequest -Uri $url -OutFile $aTubeInstaller -UseBasicParsing -TimeoutSec 90
            if (Test-Path $aTubeInstaller) {
                $fileSize = (Get-Item $aTubeInstaller).Length
                if ($fileSize -gt 1048576) { # Al menos 1MB
                    $downloadSuccess = $true
                    break
                }
            }
        } catch {
            Write-Host "       [!] Servidor no disponible, probando alternativo..." -ForegroundColor Yellow
        }
    }

    if ($downloadSuccess) {
        try {
            Write-Host "    -> Ejecutando instalador silencioso de aTube Catcher..." -ForegroundColor White
            # InnoSetup flags para instalación 100% silenciosa y sin reinicio
            $process = Start-Process -FilePath $aTubeInstaller -ArgumentList "/VERYSILENT /SUPPRESSMSGBOXES /NORESTART /SP-" -Wait -PassThru
            Write-Host "       [OK] aTube Catcher instalado (Código: $($process.ExitCode))." -ForegroundColor Green
        } catch {
            Write-Host "       [!] Error al ejecutar instalador de aTube Catcher: $_" -ForegroundColor Red
        }
    } else {
        Write-Host "       [!] No se pudo descargar aTube Catcher. Revisa tu conexión a Internet." -ForegroundColor Red
    }
}

# ==========================================
# 3. Instalación desatendida de Microsoft Office 2024
# ==========================================
Write-Host ""
if (Test-Office2024Installed) {
    Write-Host "[=] Microsoft Office LTSC 2024 ya está instalado. Se omite." -ForegroundColor DarkGray
} else {
    Write-Host "[+] Preparando despliegue de Microsoft Office 2024 (LTSC)..." -ForegroundColor Green

    $odtDir = "$WorkDir\ODT"
    if (-not (Test-Path $odtDir)) {
        New-Item -ItemType Directory -Path $odtDir -Force | Out-Null
    }

    $odtInstaller = "$WorkDir\officedeploymenttool.exe"
    # Enlace oficial directo de Microsoft a la herramienta Office Deployment Tool (ODT)
    $odtUrl = "https://download.microsoft.com/download/6c1eeb25-cf8b-41d9-8d0d-cc1dbc032140/officedeploymenttool_20430-20146.exe"

    try {
        Write-Host "    -> Descargando Office Deployment Tool (ODT)..." -ForegroundColor White
        Invoke-WebRequest -Uri $odtUrl -OutFile $odtInstaller -UseBasicParsing -TimeoutSec 60

        Write-Host "    -> Extrayendo setup.exe de Office..." -ForegroundColor White
        Start-Process -FilePath $odtInstaller -ArgumentList "/extract:`"$odtDir`" /quiet" -Wait

        # Configuración XML para Office 2024 ProPlus Volume (64 bits, Español)
        # Se genera mediante un array de cadenas para evitar incompatibilidades de saltos de línea (CRLF/LF)
        $configXmlPath = "$odtDir\configuration.xml"
        $configXmlLines = @(
            '<Configuration>'
            '  <Add OfficeClientEdition="64" Channel="PerpetualVL2024">'
            '    <Product ID="ProPlus2024Volume">'
            '      <Language ID="es-es" />'
            '      <ExcludeApp ID="Lync" />'
            '    </Product>'
            '  </Add>'
            '  <RemoveMSI />'
            '  <Display Level="None" AcceptEULA="TRUE" />'
            '  <Property Name="AUTOACTIVATE" Value="0" />'
            '</Configuration>'
        )
        $configXmlLines | Set-Content -Path $configXmlPath -Encoding UTF8

        $setupExe = "$odtDir\setup.exe"
        if (Test-Path $setupExe) {
            Write-Host "    -> Descargando e instalando Office 2024 en segundo plano..." -ForegroundColor White
            Write-Host "       (Descargando Word, Excel, PowerPoint, Outlook, etc. Esto puede tardar varios minutos)..." -ForegroundColor DarkGray

            $officeProcess = Start-Process -FilePath $setupExe -ArgumentList "/configure `"$configXmlPath`"" -Wait -PassThru
            if ($officeProcess.ExitCode -eq 0) {
                Write-Host "       [OK] Microsoft Office 2024 instalado correctamente." -ForegroundColor Green
            } else {
                Write-Host "       [!] Office finalizó con código: $($officeProcess.ExitCode)" -ForegroundColor Yellow
            }
        } else {
            Write-Host "       [-] No se encontró setup.exe de Office tras la extracción." -ForegroundColor Red
        }
    } catch {
        Write-Host "       [!] Error durante la instalación de Office 2024: $_" -ForegroundColor Red
    }
}

# ==========================================
# 4. Limpieza de archivos temporales
# ==========================================
Write-Host ""
Write-Host "[+] Limpiando archivos temporales..." -ForegroundColor Green
try {
    Remove-Item -Path $WorkDir -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host "    [OK] Directorio temporal eliminado ($WorkDir)." -ForegroundColor Green
} catch {
    Write-Host "    [i] Algunos archivos temporales se limpiarán en el próximo reinicio." -ForegroundColor Gray
}

Write-Host ""
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "   ¡PROCESO DE INSTALACIÓN FINALIZADO!                    " -ForegroundColor Green
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "Presione ENTER para salir..." -ForegroundColor Yellow

# Pausa final segura: Read-Host funciona tanto en consola interactiva como en
# sesiones redirigidas y evita los problemas de parseo de ReadKey en PowerShell 5.1.
$null = Read-Host
