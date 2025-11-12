<#
.SYNOPSIS
    Script INTERACTIVO MODULAR para configurar O revertir estaciones de trabajo. (V11)
    
.DESCRIPTION
    Permite seleccionar individualmente entre aplicar o revertir:
    - Configuración de AutoAdminLogon.
    - Directivas de Google Chrome (Perfiles Efímeros).
    - Tareas de Apagado Programado (con validación de hora por turno).
    
    Requiere privilegios de Administrador.

.EXAMPLE
    (irm https://.../script.ps1) | iex

.NOTES
    Autor: Gemini
    Versión: 11.0
    - (V11) CORRECCIÓN CRÍTICA: Se eliminó el parámetro '-ErrorAction' de 'schtasks.exe' (no es un cmdlet).
    - (V11) CORRECCIÓN CRÍTICA: Se eliminó el parámetro '/P ""' de la creación de la tarea de AVISO.
      'schtasks.exe' no acepta '/P' si la contraseña está en blanco; se debe omitir.
    - Se redirigió la salida de error (2>$null) en 'schtasks' para suprimir mensajes de "tarea no encontrada".
    - (V10) Lógica de dos tareas (WARN + SHUTDOWN) para 'Session 0 Isolation'.
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

# (V10) Nombres de tareas
$TaskMañana_WARN = "SchoolShutdown_Mañana_WARN"
$TaskMañana_SHUTDOWN = "SchoolShutdown_Mañana_SHUTDOWN"
$TaskTarde_WARN = "SchoolShutdown_Tarde_WARN"
$TaskTarde_SHUTDOWN = "SchoolShutdown_Tarde_SHUTDOWN"
$TaskVespertino_WARN = "SchoolShutdown_Vespertino_WARN"
$TaskVespertino_SHUTDOWN = "SchoolShutdown_Vespertino_SHUTDOWN"

# (V10) Ubicación del script de AVISO
$WarningScriptFile = "C:\Windows\Temp\_SchoolShutdown_WARNING.ps1"
# (V11) Corregido a un nombre de usuario más simple, sin '.\'
$UsuarioDeLogon = "Alumno_Invitado" 


# --- FUNCIONES DE AUTOLOGON ---
function Apply-AutoLogon {
    # ... (Sin cambios respecto a V10, pero usando la variable $UsuarioDeLogon actualizada)
    Write-Host ">> Aplicando configuración de Autologon..." -ForegroundColor Cyan
    try {
        Set-ItemProperty -Path $KeyPathAutoLogon -Name "DefaultUserName" -Value $UsuarioDeLogon -Type String -Force
        Write-Host "   -> DefaultUserName: '$UsuarioDeLogon'"
        Set-ItemProperty -Path $KeyPathAutoLogon -Name "DefaultPassword" -Value "" -Type String -Force
        Write-Host "   -> DefaultPassword: (vacío)"
        Set-ItemProperty -Path $KeyPathAutoLogon -Name "AutoAdminLogon" -Value "1" -Type String -Force
        Write-Host "   -> AutoAdminLogon: Habilitado (1)"
        Write-Host "   [OK] Autologon aplicado correctamente." -ForegroundColor Green
    } catch { Write-Error "   [ERROR] Falló Autologon: $_" }
}

function Revert-AutoLogon {
    # ... (Sin cambios)
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
    # ... (Sin cambios)
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
    # ... (Sin cambios)
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

# --- (ACTUALIZADO V11) FUNCIONES DE APAGADO PROGRAMADO ---

# Función de limpieza (ACTUALIZADA V11)
function Revert-ShutdownTasks {
    Write-Host ">> Eliminando Tareas de Apagado Programado existentes..." -ForegroundColor Yellow
    try {
        # 1. Eliminar Tareas (Sin -ErrorAction, con 2>$null)
        Write-Host "   -> Limpiando tareas..."
        schtasks /Delete /TN $TaskMañana_WARN /F 2>$null
        schtasks /Delete /TN $TaskMañana_SHUTDOWN /F 2>$null
        schtasks /Delete /TN $TaskTarde_WARN /F 2>$null
        schtasks /Delete /TN $TaskTarde_SHUTDOWN /F 2>$null
        schtasks /Delete /TN $TaskVespertino_WARN /F 2>$null
        schtasks /Delete /TN $TaskVespertino_SHUTDOWN /F 2>$null
        Write-Host "   [OK] Tareas de apagado anteriores eliminadas."

        # 2. Eliminar el script de AVISO
        if (Test-Path $WarningScriptFile) {
            Remove-Item -Path $WarningScriptFile -Force -ErrorAction SilentlyContinue
            Write-Host "   [OK] Script de aviso ($WarningScriptFile) eliminado."
        }

    } catch {
        # Este catch ahora solo se aplica a la eliminación del archivo
        Write-Error "   [ERROR] Falló la eliminación de tareas: $_"
    }
}

# Función auxiliar para validar la hora (Sin cambios)
function Get-ValidatedTime($ShiftName, $StartTime, $EndTime) {
    $StartTimeSpan = [TimeSpan]$StartTime
    $EndTimeSpan = [TimeSpan]$EndTime
    $ValidTime = $null

    do {
        $InputTimeStr = Read-Host "   -> Introduzca la HORA DE APAGADO para el Turno $ShiftName (HH:MM) [ej. $EndTime]"
        
        try {
            $InputTimeSpan = [TimeSpan]::ParseExact($InputTimeStr, "hh\:mm", $null)
            
            if ($InputTimeSpan -ge $StartTimeSpan -and $InputTimeSpan -le $EndTimeSpan) {
                $ValidTime = $InputTimeSpan
                Write-Host "      Hora válida: $InputTimeStr" -ForegroundColor Green
            } else {
                Write-Warning "      Error: La hora '$InputTimeStr' está fuera del rango ($StartTime - $EndTime)."
            }
        } catch {
            Write-Warning "      Error: Formato de hora no válido. Use HH:MM (24hs)."
        }
    } while ($ValidTime -eq $null)
    
    return $ValidTime
}

# (V10) Función auxiliar para reparar dependencias
function Repair-MessagingServices {
    Write-Host "   -> Verificando servicios de mensajería (TermService, AllowRemoteRPC)..."
    try {
        # 1. TermService
        $TermService = Get-Service -Name "TermService" -ErrorAction Stop
        if ($TermService.Status -ne "Running") {
            Write-Warning "      'TermService' no está en ejecución. Iniciando..."
            Set-Service -Name "TermService" -StartupType Automatic -ErrorAction Stop
            Start-Service -Name "TermService" -ErrorAction Stop
            Write-Host "      'TermService' iniciado y en Automático." -ForegroundColor Green
        }
        
        # 2. AllowRemoteRPC
        $RegPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server"
        $RegKey = "AllowRemoteRPC"
        $RegValue = (Get-ItemProperty -Path $RegPath -Name $RegKey -ErrorAction SilentlyContinue).$RegKey
        if ($RegValue -ne 1) {
             Write-Warning "      'AllowRemoteRPC' no está en 1. Corrigiendo..."
             New-ItemProperty -Path $RegPath -Name $RegKey -Value 1 -Type DWord -Force -ErrorAction Stop
             Write-Host "      'AllowRemoteRPC' establecido en 1." -ForegroundColor Green
        }
    } catch { Write-Error "      [ERROR] Falló la reparación de servicios: $_" }
    Write-Host ""
}


# Función principal de aplicación (ACTUALIZADA V11)
function Apply-ShutdownTasks {
    Write-Host ">> Configurando Tareas de Apagado Programado (V11 - Dos Tareas)..." -ForegroundColor Cyan
    
    # 1. Limpiar tareas anteriores
    Revert-ShutdownTasks
    Write-Host ""

    # 2. Reparar servicios
    Repair-MessagingServices

    # 3. Definir el script de AVISO
    $PayloadScriptString = @"
# --- Script de Aviso Progresivo (Ejecutado como Alumno_Invitado) ---
Add-Type -AssemblyName Microsoft.VisualBasic

\$wshell = New-Object -ComObject WScript.Shell

# T-10: Primer Aviso (10 segundos de visibilidad, icono de Advertencia)
\$wshell.Popup("AVISO (10 MIN): La notebook debe ser devuelta. Guarde su trabajo. Se apagará en 10 minutos.", 10, "Aviso de Apagado (1/3)", 0x30)
Start-Sleep -Seconds 300 # Esperar 5 min

# T-5: Segundo Aviso
\$wshell.Popup("AVISO (5 MIN): Guarde su trabajo. El equipo se apagará en 5 minutos.", 10, "Aviso de Apagado (2/3)", 0x30)
Start-Sleep -Seconds 240 # Esperar 4 min

# T-1: Aviso Final
\$wshell.Popup("AVISO FINAL (1 MIN): APAGADO INMINENTE. Cierre todo ahora.", 10, "Aviso de Apagado (3/3)", 0x10) # 0x10 Icono de Error (Stop)
"@

    # 4. Guardar el script de AVISO en un archivo
    try {
        $PayloadScriptString | Out-File -FilePath $WarningScriptFile -Encoding utf8 -Force
        Write-Host "   -> Script de aviso guardado en: $WarningScriptFile"
    } catch {
        Write-Error "   [ERROR] No se pudo escribir el script en $WarningScriptFile. $_"
        Write-Error "   Saliendo de la configuración de tareas."
        return
    }

    # 5. Definir los comandos de las tareas
    $TaskRunCommand_WARN = "powershell.exe -WindowStyle Hidden -ExecutionPolicy Bypass -File ""$WarningScriptFile"""
    $TaskRunCommand_SHUTDOWN = "shutdown.exe /s /f /t 0"

    Write-Host "   -> Tarea de Aviso (Usuario): $TaskRunCommand_WARN"
    Write-Host "   -> Tarea de Apagado (SYSTEM): $TaskRunCommand_SHUTDOWN"
    Write-Host ""
    
    # 6. Definir límites de los turnos
    $Shifts = @{
        Mañana = @{ W=$TaskMañana_WARN; S=$TaskMañana_SHUTDOWN; Start="07:35"; End="12:15" }
        Tarde = @{ W=$TaskTarde_WARN; S=$TaskTarde_SHUTDOWN; Start="12:25"; End="17:05" }
        Vespertino = @{ W=$TaskVespertino_WARN; S=$TaskVespertino_SHUTDOWN; Start="17:15"; End="21:40" }
    }

    Write-Host "Seleccione los turnos para configurar el apagado automático:"
    
    # (V11) Se envuelve la creación de tareas en un Try/Catch
    try {
        # --- Configuración Turno Mañana ---
        if ((Read-Host "   ¿Configurar Turno Mañana (07:35-12:15)? (s/n)") -eq 's') {
            $Shift = $Shifts.Mañana
            $ShutdownTime = Get-ValidatedTime "Mañana" $Shift.Start $Shift.End
            $WarnTime = $ShutdownTime.Add([TimeSpan]::FromMinutes(-10)).ToString("hh\:mm")
            
            Write-Host "     -> Creando Tarea AVISO '$($Shift.W)' (Usuario: $UsuarioDeLogon) a las $WarnTime"
            # (V11) CORRECCIÓN: Se eliminó el parámetro '/P ""'.
            schtasks /Create /TN $Shift.W /TR $TaskRunCommand_WARN /SC DAILY /ST $WarnTime /RU $UsuarioDeLogon /F /RL LIMITED 2>$null
            
            Write-Host "     -> Creando Tarea APAGADO '$($Shift.S)' (SYSTEM) a las $($ShutdownTime.ToString("hh\:mm"))"
            schtasks /Create /TN $Shift.S /TR $TaskRunCommand_SHUTDOWN /SC DAILY /ST $($ShutdownTime.ToString("hh\:mm")) /RU "SYSTEM" /F /RL HIGHEST 2>$null
        }

        # --- Configuración Turno Tarde ---
        if ((Read-Host "   ¿Configurar Turno Tarde (12:25-17:05)? (s/n)") -eq 's') {
            $Shift = $Shifts.Tarde
            $ShutdownTime = Get-ValidatedTime "Tarde" $Shift.Start $Shift.End
            $WarnTime = $ShutdownTime.Add([TimeSpan]::FromMinutes(-10)).ToString("hh\:mm")
            
            Write-Host "     -> Creando Tarea AVISO '$($Shift.W)' (Usuario: $UsuarioDeLogon) a las $WarnTime"
            # (V11) CORRECCIÓN: Se eliminó el parámetro '/P ""'.
            schtasks /Create /TN $Shift.W /TR $TaskRunCommand_WARN /SC DAILY /ST $WarnTime /RU $UsuarioDeLogon /F /RL LIMITED 2>$null
            
            Write-Host "     -> Creando Tarea APAGADO '$($Shift.S)' (SYSTEM) a las $($ShutdownTime.ToString("hh\:mm"))"
            schtasks /Create /TN $Shift.S /TR $TaskRunCommand_SHUTDOWN /SC DAILY /ST $($ShutdownTime.ToString("hh\:mm")) /RU "SYSTEM" /F /RL HIGHEST 2>$null
        }

        # --- Configuración Turno Vespertino ---
        if ((Read-Host "   ¿Configurar Turno Vespertino (17:15-21:40)? (s/n)") -eq 's') {
            $Shift = $Shifts.Vespertino
            $ShutdownTime = Get-ValidatedTime "Vespertino" $Shift.Start $Shift.End
            $WarnTime = $ShutdownTime.Add([TimeSpan]::FromMinutes(-10)).ToString("hh\:mm")

            Write-Host "     -> Creando Tarea AVISO '$($Shift.W)' (Usuario: $UsuarioDeLogon) a las $WarnTime"
            # (V11) CORRECCIÓN: Se eliminó el parámetro '/P ""'.
            schtasks /Create /TN $Shift.W /TR $TaskRunCommand_WARN /SC DAILY /ST $WarnTime /RU $UsuarioDeLogon /F /RL LIMITED 2>$null
            
            Write-Host "     -> Creando Tarea APAGADO '$($Shift.S)' (SYSTEM) a las $($ShutdownTime.ToString("hh\:mm"))"
            schtasks /Create /TN $Shift.S /TR $TaskRunCommand_SHUTDOWN /SC DAILY /ST $($ShutdownTime.ToString("hh\:mm")) /RU "SYSTEM" /F /RL HIGHEST 2>$null
        }
        
        Write-Host ""
        Write-Host "   [OK] Tareas de apagado V11 (Aviso + Apagado) configuradas." -ForegroundColor Green
    
    } catch {
        Write-Error "   [ERROR] Falló la creación de tareas programadas V11: $_"
        Write-Warning "   Asegúrese de que el usuario '$UsuarioDeLogon' existe y que su contraseña está en blanco."
    }
}

# =================================================================
# SECCIÓN 3: MENÚ INTERACTIVO PRINCIPAL
# =================================================================
Clear-Host
Write-Host "=================================================================" -ForegroundColor Cyan
Write-Host "      GESTIÓN DE ESTACIONES DE TRABAJO - ESCUELA (V11)"
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
Write-Host "   [7] Aplicar/Actualizar Tareas de Apagado (V11)" -ForegroundColor Magenta
Write-Host "   [8] Revertir TODAS las Tareas de Apagado" -ForegroundColor Magenta
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
        Apply-ShutdownTasks # Esta función es interactiva
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
    '7' { Apply-ShutdownTasks }   # Llama a la función V11
    '8' { Revert-ShutdownTasks }  # Llama a la función de borrado V11
    'Q' { Write-Host "Saliendo sin cambios." -ForegroundColor Gray; exit }
    'q' { Write-Host "Saliendo sin cambios." -ForegroundColor Gray; exit }
    default { Write-Warning "Opción no válida. No se realizaron cambios." }
}

# =================================================================
# FIN
# =================================================================
Write-Host ""
Write-Host "=================================================================" -ForegroundColor Green
Write-Host "Proceso finalizado."
Write-Host "Si aplicó cambios, recuerde:"
Write-Host " - Autologon: Requiere reiniciar Windows."
Write-Host " - Chrome: Requiere reiniciar el navegador."
Write-Host " - Tareas Apagado (V11): Se han creado tareas de AVISO (como '$UsuarioDeLogon')"
Write-Host "   y tareas de APAGADO (como 'SYSTEM')."
Write-Host "================================================================="