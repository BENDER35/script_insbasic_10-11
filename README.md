# 🚀 Instalador Desatendido de Software para Windows 10 y 11

Este proyecto proporciona un sistema de instalación silenciosa y desatendida diseñado para configurar rápidamente un equipo nuevo o recién formateado con Windows 10 o Windows 11.

---

## 📦 Software Incluido

El script automatiza la descarga e instalación de las siguientes herramientas esenciales:

| Software | Método | Descripción |
| :--- | :--- | :--- |
| **Google Chrome** | WinGet (`Google.Chrome`) | Navegador web de Google |
| **7-Zip** | WinGet (`7zip.7zip`) | Compresor y descompresor de archivos de alto rendimiento |
| **Adobe Acrobat Reader (64-bit)** | WinGet (`Adobe.Acrobat.Reader.64-bit`) | Visor estándar de documentos PDF |
| **VLC Media Player** | WinGet (`VideoLAN.VLC`) | Reproductor multimedia universal |
| **K-Lite Codec Pack Standard** | WinGet (`CodecGuide.K-LiteCodecPack.Standard`) | Paquete completo de filtros y códecs de audio/vídeo |
| **Topgrade** | WinGet (`topgrade-rs.topgrade`) | Gestor de actualización unificada de sistemas y paquetes |
| **Zoom** | WinGet (`Zoom.Zoom`) | Plataforma de videoconferencias y reuniones online |
| **Microsoft Teams** | WinGet (`Microsoft.Teams`) | Cliente de colaboración, chat y reuniones (nueva app de Teams) |
| **AnyDesk** | WinGet (`AnyDeskSoftwareGmbH.AnyDesk`) | Escritorio remoto para soporte y acceso a distancia |
| **RustDesk** | WinGet (`RustDesk.RustDesk`) | Escritorio remoto de código abierto, con opción de servidor propio |
| **scrcpy** | WinGet (`Genymobile.scrcpy`) | Control y espejo de dispositivos Android por USB o Wi-Fi |
| **aTube Catcher** | Descarga directa + InnoSetup | Descargador y convertidor multimedia |
| **Microsoft Office LTSC 2024** | Microsoft ODT + XML (64-bit, ES) | Word, Excel, PowerPoint, Outlook (LTSC ProPlus Volumen) |

---

## 📋 Requisitos Previos

- **Sistema Operativo:** Windows 10 (versión 1809 o superior) o Windows 11 (64 bits).
- **Permisos:** Privilegios de **Administrador**.
- **Conexión a Internet:** Activa y estable durante todo el proceso.
- **Espacio en disco:** Mínimo 5-10 GB libres para la descarga e instalación de Office y el resto de programas.

---

## 🔐 Política de Ejecución de PowerShell

Tanto `ejecutar_instalador.bat` como `instalar_programas.ps1` comprueban la política de ejecución antes de continuar:

| Situación | Comportamiento |
| :--- | :--- |
| Política impuesta por **GPO** (`MachinePolicy` o `UserPolicy`) | No se modifica; se avisa y se continúa con `-ExecutionPolicy Bypass`. |
| Política distinta de `Unrestricted` (sin GPO) | Se establece **`Unrestricted`** en los ámbitos `LocalMachine` y `CurrentUser`. |
| Política ya `Unrestricted` | Se muestra confirmación y no se cambia nada. |

De este modo, tras la primera ejecución se podrán lanzar directamente cualesquiera scripts `.ps1` del equipo.

Si en algún momento quieres revertir el cambio a un valor más seguro:

```powershell
Set-ExecutionPolicy -Scope LocalMachine -ExecutionPolicy RemoteSigned -Force
Set-ExecutionPolicy -Scope CurrentUser  -ExecutionPolicy Undefined -Force
```

> ⚠️ **Aviso de seguridad:** `Unrestricted` permite ejecutar cualquier script, incluso sin firma digital. En equipos corporativos o compartidos es preferible `RemoteSigned`, que solo exige firma a los scripts descargados de Internet.

---

## 🚀 Instrucciones de Uso

### Método 1: Doble clic (Recomendado)
1. Descarga o descomprime la carpeta en cualquier ubicación (por ejemplo, `Descargas` o `Escritorio`).
2. Haz clic derecho sobre **`ejecutar_instalador.bat`** y selecciona **"Ejecutar como administrador"** (o simplemente haz doble clic; el script solicitará elevación automáticamente mediante UAC).
3. Acepta el cuadro de diálogo de Control de Cuentas de Usuario (UAC).
4. El proceso comenzará en la consola de PowerShell y se ejecutará de forma desatendida.
5. Al finalizar, presiona **ENTER** para cerrar la ventana.

### Método 2: Desde PowerShell
1. Abre **PowerShell como Administrador** (Win + X > Terminal / PowerShell como Administrador).
2. Navega hasta la carpeta del proyecto:
   ```powershell
   cd "C:\Ruta\A\sc_basic_11"
   ```
3. Ejecuta el script omitiendo la política de ejecución:
   ```powershell
   powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\instalar_programas.ps1
   ```

---

## 🛠️ Estructura del Repositorio

- **[`ejecutar_instalador.bat`](ejecutar_instalador.bat)**: Lanzador por lotes que comprueba permisos de administrador, eleva privilegios y lanza PowerShell con `ExecutionPolicy Bypass`.
- **[`instalar_programas.ps1`](instalar_programas.ps1)**: Script principal en PowerShell encargado de gestionar paquetes WinGet, descargas web, configuración XML e instalación de Office.
- **[`GUIA_DIDACTICA.md`](GUIA_DIDACTICA.md)**: Manual técnico y didáctico que explica detalladamente el funcionamiento interno del script, sintaxis de PowerShell, gestión de instaladores silenciosos y resolución de errores.

---

## 🔍 Resolución del Error Detectado (`err.txt`)

### ¿Qué error se produjo?
```text
En C:\Users\...\instalar_programas.ps1: 182 Carácter: 54
+ $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
+                                                      ~~
Falta la cadena en el terminador: ".
    + CategoryInfo          : ParserError: (:) [], ParseException
    + FullyQualifiedErrorId : TerminatorExpectedAtEndOfString
```

### ¿Por qué ocurrió?
1. **Conflicto de saltos de línea (LF vs CRLF) en *Here-Strings* (`@" ... "@`):**
   En Windows PowerShell 5.1 (el motor por defecto de Windows), los delimitadores de bloque multilínea (*here-strings*) son extremadamente estrictos. Si el archivo se guarda con terminaciones de línea Unix (`LF` en lugar de `CRLF`), o si el delimitador de cierre `"@` tiene cualquier espacio o sangría por delante, PowerShell no detecta el cierre del bloque.
2. **Efecto dominó hacia el final del archivo:**
   Al no detectar el cierre del XML de Office en la línea 144, PowerShell interpretó todo el código restante como parte del texto de la cadena. Al alcanzar el final absoluto del archivo (la línea 182), lanzó el error de sintaxis `TerminatorExpectedAtEndOfString`.
3. **Falsa pista en la línea 182:**
   La línea 182 contenía `$Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")`. El error parecía señalar a esa línea por ser el punto donde terminaba el archivo, pero el fallo real estaba decenas de líneas más arriba en el *here-string*.

### Correcciones aplicadas:
- Se reemplazó el bloque *here-string* por un array estructurado de cadenas (`@('...') | Set-Content`), eliminando para siempre la vulnerabilidad a problemas de sangría o saltos de línea LF/CRLF.
- Se actualizaron los enlaces oficiales de descarga de **Office Deployment Tool (ODT)** (el enlace anterior devolvía error HTTP 404) y de **aTube Catcher** (el subdominio original ya no resolvía).
- Se implementó una detección avanzada para **WinGet** que funciona incluso cuando se ejecuta bajo cuentas de Administrador elevadas donde `%LOCALAPPDATA%\Microsoft\WindowsApps` no está registrado en el PATH.
- Se estandarizaron todos los scripts con finales de línea `CRLF` (Windows estándar).
- Se sustituyó la pausa final `$Host.UI.RawUI.ReadKey(...)` por `Read-Host`, que no depende de la API de consola y funciona igual en consolas interactivas, sesiones elevadas y entornos redirigidos.
- Se guardó el archivo `.ps1` en **UTF-8 con BOM**, de modo que Windows PowerShell 5.1 interpreta correctamente los acentos y símbolos del español.
- Se añadió una comprobación de la **política de ejecución**: si no está impuesta por GPO, se establece `Unrestricted` en `LocalMachine` y `CurrentUser`; si ya lo está, se confirma sin cambios.

---

## 🆕 Última Actualización: Zoom, Teams, AnyDesk, RustDesk y scrcpy

Se han añadido cinco aplicaciones al despliegue mediante WinGet:

| Aplicación | ID de WinGet | Notas |
| :--- | :--- | :--- |
| **Zoom** | `Zoom.Zoom` | Instala el cliente de escritorio de Zoom. |
| **Microsoft Teams** | `Microsoft.Teams` | Instala la **nueva aplicación de Teams** (cliente MSIX, trabajo o centro educativo). |
| **AnyDesk** | `AnyDeskSoftwareGmbH.AnyDesk` | Cliente de escritorio remoto. Puede requerir configurar una contraseña de acceso desatendido en su interfaz. |
| **RustDesk** | `RustDesk.RustDesk` | Escritorio remoto de código abierto. Funciona sin configuración con los servidores públicos; admite servidor propio. |
| **scrcpy** | `Genymobile.scrcpy` | Utilidad portable para ver y controlar un Android desde el PC. |

> **Nota sobre Teams:** la instalación requiere que el componente **"Instalador de aplicaciones" (App Installer)** esté actualizado, ya que la nueva app de Teams se distribuye como paquete MSIX. Si el equipo usa la versión de consumidor (*Teams gratis*), puede cambiarse el ID por el que corresponda a esa variante.
>
> **Nota sobre AnyDesk y RustDesk:** ambos instalan un servicio de acceso remoto. Para poder conectarte **sin que nadie acepte** la sesión en el equipo remoto, hay que establecer una contraseña de acceso desatendido en la interfaz de cada programa. RustDesk permite además configurar un **servidor propio (self-hosted)** si no se desea usar la infraestructura pública.
>
> **Nota sobre scrcpy:** se instala como aplicación **portable** (ZIP) y añade el alias `scrcpy` al PATH. Para usarlo necesitas un dispositivo Android con **Depuración USB** activada y el **ADB** incluido en el paquete de scrcpy. Conexión típica:
> ```powershell
> scrcpy              # dispositivo conectado por USB
> adb devices         # comprobar que el dispositivo aparece autorizado
> ```
> Para conexión inalámbrica, primero empareja el dispositivo con `adb pair` y luego conéctalo con `adb connect <IP>:<puerto>`.
>
> Para comprobar los identificadores disponibles en tu equipo puedes ejecutar:
> ```powershell
> winget search Zoom
> winget search Teams
> winget search AnyDesk
> winget search RustDesk
> winget search scrcpy
> ```

---

## ♻️ Omisión de programas ya instalados (Idempotencia)

El script es **idempotente**: puede ejecutarse varias veces sobre el mismo equipo sin reinstalar lo que ya está presente. Antes de instalar cada aplicación comprueba su estado y, si ya existe, muestra un aviso y pasa a la siguiente:

```text
    [=] Google Chrome ya está instalado. Se omite.
```

### Cómo se detecta cada tipo de software

| Software | Método de detección |
| :--- | :--- |
| Paquetes de **WinGet** (Chrome, 7-Zip, Adobe, VLC, K-Lite, Topgrade, Zoom, AnyDesk, RustDesk, scrcpy) | `winget list --id <ID> -e` y comprobación del código de salida |
| **Microsoft Teams** | `Get-AppxPackage -Name MSTeams` (paquete MSIX) y, como respaldo, WinGet |
| **aTube Catcher** | Búsqueda en el registro de Windows (`Uninstall`) por nombre |
| **Microsoft Office LTSC 2024** | Clave `HKLM:\SOFTWARE\Microsoft\Office\ClickToRun\Configuration` (`ProductReleaseIds`) |

### Funciones implicadas

- `Test-WingetAppInstalled`: consulta WinGet y, opcionalmente, un paquete Appx.
- `Test-SoftwareInstalled`: recorre las tres ramas del registro de desinstalación (HKLM 64 bits, HKLM 32 bits y HKCU).
- `Test-Office2024Installed`: verifica si Office 2024 ProPlus Volume está desplegado con Click-to-Run.

> **Ventaja:** además de ahorrar tiempo, se evita descargar de nuevo Office o los instaladores externos, y se reduce el riesgo de errores por reinstalar sobre una versión en uso.
