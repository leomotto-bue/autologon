<#
.SYNOPSIS
    Script INTERACTIVO MODULAR para configurar O revertir estaciones de trabajo.
    
.DESCRIPTION
    Permite seleccionar individualmente entre aplicar o revertir:
    - Configuración de AutoAdminLogon.
    - Directivas de Google Chrome (Perfiles Efímeros).
    - Tareas de Apagado Programado (con aviso de 5 min).
    
    Requiere privilegios de Administrador.

.EXAMPLE
    (irm https://.../script.ps1) | iex

.NOTES
    Autor: Gemini
    Versión: 5.0
#>

# =================================================================
# SECCIÓN 1: VERIFICACIÓN DE ADMINISTRADOR
# =================================================================
Write-Host "Verificando privilegios de Administrador..." -ForegroundColor Yellow

if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Error "ACCESO DENEGADO: Este script debe ejecutarse como Administrador."
    Write-Warning "Por favor, reinicie su terminal de PowerShell como 'Administrador'."
    if ($Host.Name -eq "ConsoleHost") { Read-Host "Presione Enter para salir..." }
    exit 1
}
Write-Host "Privilegios de Administrador confirmados." -ForegroundColor Green
Write-Host ""

# =================================================================
# SECCIÓN 2: VARIABLES Y FUNCIONES MODULARES
# =================================================================

# --- Variables Globales ---
$KeyPathAutoLogon = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"
$ChromePolicyPath = "HKLM:\SOFTWARE\Policies\Google\Chrome"
$ChromePolicyParentPath = "HKLM:\SOFTWARE\Policies\Google"

# --- FUNCIONES DE AUTOLOGON ---
function Apply-AutoLogon {
    Write-Host ">> Aplicando configuración de Autologon..." -ForegroundColor Cyan
    try {
        Set-ItemProperty -Path $KeyPathAutoLogon -Name "DefaultUserName" -Value ".\Alumno_Invitado" -Type String -Force
        Write-Host "   -> DefaultUserName: '.\Alumno_Invitado'"
        Set-ItemProperty -Path $KeyPathAutoLogon -Name "DefaultPassword" -Value "" -Type String -Force
        Write-Host "   -> DefaultPassword: (vacío)"
        Set-ItemProperty -Path $KeyPathAutoLogon -Name "AutoAdminLogon" -Value "1" -Type String -Force
        Write-Host "   -> AutoAdminLogon: Habilitado (1)"
        Write-Host "   [OK] Autologon aplicado correctamente." -ForegroundColor Green
    } catch { Write-Error "   [ERROR] Falló Autologon: $_" }
}

function Revert-AutoLogon {
    Write-Host ">> Revirtiendo configuración de Autologon..." -ForegroundColor Yellow
    try {
        Set-ItemProperty -Path $KeyPathAutoLogon -Name "AutoAdminLogon" -Value "0" -Type String -Force
        Write-Host "   -> AutoAdminLogon: Deshabilitado (0)"
        Remove-ItemProperty -Path $KeyPathAutoLogon -Name "DefaultUserName" -ErrorAction SilentlyContinue
        Remove-ItemProperty -Path $KeyPathAutoLogon -Name "DefaultPassword" -ErrorAction SilentlyContinue
        Write-Host "   -> Credenciales eliminadas."
        Write-Host "   [OK] Autologon revertido correctamente." -ForegroundColor Green
    } catch { Write-Error "   [ERROR] Falló reversión Autologon: $_" }
}

# --- FUNCIONES DE CHROME ---
function Apply-Chrome {
    Write-Host ">> Aplicando directivas de Google Chrome..." -ForegroundColor Cyan
    try {
        if (-not (Test-Path $ChromePolicyPath)) {
            New-Item -Path $ChromePolicyParentPath -Name "Chrome" -Force -ErrorAction Stop | Out-Null
        }
        Set-ItemProperty -Path $ChromePolicyPath -Name "ForceEphemeralProfiles" -Value 1 -Type DWord -Force -ErrorAction Stop
        Write-Host "   -> ForceEphemeralProfiles: Activado (1)"
        Set-ItemProperty -Path $ChromePolicyPath -Name "SyncDisabled" -Value 1 -Type DWord -Force -ErrorAction Stop
        Write-Host "   -> SyncDisabled: Activado (1)"
        Set-ItemProperty -Path $ChromePolicyPath -Name "BrowserSignin" -Value 0 -Type DWord -Force -ErrorAction Stop
        Write-Host "   -> BrowserSignin: Desactivado (0)"
        Write-Host "   [OK] Directivas Chrome aplicadas correctamente." -ForegroundColor Green
    } catch { Write-Error "   [ERROR] Falló directivas Chrome: $_" }
}

function Revert-Chrome {
    Write-Host ">> Revirtiendo directivas de Google Chrome..." -ForegroundColor Yellow
    try {
        if (Test-Path $ChromePolicyPath) {
            Remove-ItemProperty -Path $ChromePolicyPath -Name "ForceEphemeralProfiles" -ErrorAction SilentlyContinue
            Remove-ItemProperty -Path $ChromePolicyPath -Name "SyncDisabled" -ErrorAction SilentlyContinue
            Remove-ItemProperty -Path $ChromePolicyPath -Name "BrowserSignin" -ErrorAction SilentlyContinue
            Write-Host "   -> Directivas eliminadas del registro."
            Write-Host "   [OK] Directivas Chrome revertidas correctamente." -ForegroundColor Green
        } else { Write-Host "   -> No existen directivas de Chrome para revertir." }
    } catch { Write-Error "   [ERROR] Falló reversión Chrome: $_" }
}

# --- (NUEVO) FUNCIONES DE APAGADO PROGRAMADO ---
function Apply-ShutdownTasks {
    Write-Host ">> Configurando Tareas de Apagado Programado..." -ForegroundColor Cyan
    
    # --- Definir el comando de la tarea ---
    $WarningMessage = "AVISO DE FIN DE SESIÓN: Esta notebook debe ser devuelta al carro. Por favor, GUARDE TODO SU TRABAJO. El equipo se apagará automáticamente en 5 minutos."
    
    # El comando que se ejecutará: 1. Muestra un mensaje, 2. Inicia el apagado forzado en 300 seg (5 min).
    # Usamos msg * para enviar el mensaje a cualquier usuario activo.
    $Payload = "msg * '$WarningMessage'; shutdown.exe -s -f -t 300"
    
    # Convertimos el comando a Base64 para evitar problemas con comillas y caracteres especiales al pasarlo a schtasks
    $EncodedPayload = [Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes($Payload))
    $TaskRunCommand = "powershell.exe -WindowStyle Hidden -EncodedCommand $EncodedPayload"

    # --- Nombres de las tareas (usamos 2 por si hay turno mañana y tarde) ---
    $TaskName1 = "SchoolShutdownWarning_Task1"
    $TaskName2 = "SchoolShutdownWarning_Task2"

    # --- Entrada Interactiva ---
    Write-Host "Introduce las horas para el apagado (formato HH:MM, 24h)."
    Write-Host "Deja vacío y presiona Enter para omitir."
    $time1 = Read-Host "   - Hora 1 (p.ej., 12:00 para mediodía)"
    $time2 = Read-Host "   - Hora 2 (p.ej., 17:00 para la tarde)"

    # --- Limpiar tareas anteriores antes de crear nuevas ---
    schtasks /Delete /TN $TaskName1 /F -ErrorAction SilentlyContinue | Out-Null
    schtasks /Delete /TN $TaskName2 /F -ErrorAction SilentlyContinue | Out-Null

    # --- Crear Tareas Programadas ---
    try {
        if (-not [string]::IsNullOrWhiteSpace($time1)) {
            Write-Host "   -> Creando tarea 1 para las $time1..."
            # /RU "SYSTEM" : Ejecuta como Sistema (permisos altos)
            # /SC DAILY    : Se repite diariamente
            # /F           : Fuerza la creación (sobrescribe si existe)
            # /RL HIGHEST  : Con los privilegios más altos
            schtasks /Create /TN $TaskName1 /TR $TaskRunCommand /SC DAILY /ST $time1 /RU "SYSTEM" /F /RL HIGHEST | Out-Null
        }
        if (-not [string]::IsNullOrWhiteSpace($time2)) {
            Write-Host "   -> Creando tarea 2 para las $time2..."
            schtasks /Create /TN $TaskName2 /TR $TaskRunCommand /SC DAILY /ST $time2 /RU "SYSTEM" /F /RL HIGHEST | Out-Null
        }
        Write-Host "   [OK] Tareas de apagado configuradas." -ForegroundColor Green
    } catch {
        Write-Error "   [ERROR] Falló la creación de tareas programadas: $_"
    }
}

function Revert-ShutdownTasks {
    Write-Host ">> Revirtiendo Tareas de Apagado Programado..." -ForegroundColor Yellow
    try {
        schtasks /Delete /TN "SchoolShutdownWarning_Task1" /F -ErrorAction SilentlyContinue | Out-Null
        schtasks /Delete /TN "SchoolShutdownWarning_Task2" /F -ErrorAction SilentlyContinue | Out-Null
        Write-Host "   [OK] Tareas de apagado eliminadas." -ForegroundColor Green
    } catch {
        Write-Error "   [ERROR] Falló la eliminación de tareas: $_"
    }
}


# =================================================================
# SECCIÓN 3: MENÚ INTERACTIVO PRINCIPAL
# =================================================================
Clear-Host
Write-Host "=================================================================" -ForegroundColor Cyan
Write-Host "      GESTIÓN DE ESTACIONES DE TRABAJO - ESCUELA (V5)"
Write-Host "=================================================================" -ForegroundColor Cyan
Write-Host "Seleccione una opción:"
Write-Host ""
Write-Host "   [1] Aplicar TODO (Autologon + Chrome + Tareas Apagado)" -ForegroundColor Green
Write-Host "   [2] Revertir TODO (Autologon + Chrome + Tareas Apagado)" -ForegroundColor Yellow
Write-Host "   -----------------------------------------------------"
Write-Host "   [3] Solo Aplicar Autologon"
Write-Host "   [4] Solo Revertir Autologon"
Write-Host "   -----------------------------------------------------"
Write-Host "   [5] Solo Aplicar Chrome (Perfiles Efímeros)"
Write-Host "   [6] Solo Revertir Chrome"
Write-Host "   -----------------------------------------------------"
Write-Host "   [7] Aplicar/Actualizar Tareas de Apagado Programado" -ForegroundColor Magenta
Write-Host "   [8] Revertir Tareas de Apagado Programado" -ForegroundColor Magenta
Write-Host "   -----------------------------------------------------"
Write-Host "   [Q] Salir"
Write-Host ""

$choice = Read-Host "Su elección"

# =================================================================
# SECCIÓN 4: LÓGICA DE EJECUCIÓN
# =================================================================
Write-Host ""
switch ($choice) {
    '1' { 
        Apply-AutoLogon
        Write-Host ""
        Apply-Chrome
        Write-Host ""
        Apply-ShutdownTasks # Esta función pedirá las horas
    }
    '2' { 
        Revert-AutoLogon
        Write-Host ""
        Revert-Chrome
        Write-Host ""
        Revert-ShutdownTasks
    }
    '3' { Apply-AutoLogon }
    '4' { Revert-AutoLogon }
    '5' { Apply-Chrome }
    '6' { Revert-Chrome }
    '7' { Apply-ShutdownTasks }
    '8' { Revert-ShutdownTasks }
    'Q' { Write-Host "Saliendo sin cambios." -ForegroundColor Gray; exit }
    'q' { Write-Host "Saliendo sin cambios." -ForegroundColor Gray; exit }
    default { Write-Warning "Opción no válida. No se realizaron cambios." }
}

# =================================Dos
# FIN
# =================================================================
Write-Host ""
Write-Host "=================================================================" -ForegroundColor Green
Write-Host "Proceso finalizado."
Write-Host "Si aplicó cambios, recuerde:"
Write-Host " - Autologon: Requiere reiniciar Windows."
Write-Host " - Chrome: Requiere reiniciar el navegador."
Write-Host " - Tareas Apagado: Se ejecutarán solas en los horarios configurados."
Write-Host "================================================================="