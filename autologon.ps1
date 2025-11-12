<#
.SYNOPSIS
    Script INTERACTIVO MODULAR para configurar O revertir estaciones de trabajo. (V7)
    
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
    Versión: 7.0
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

# --- Nombres de tareas de apagado ---
$TaskMañana = "SchoolShutdown_Mañana"
$TaskTarde = "SchoolShutdown_Tarde"
$TaskVespertino = "SchoolShutdown_Vespertino"


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

# --- (ACTUALIZADO V7) FUNCIONES DE APAGADO PROGRAMADO ---

# Función de limpieza (no cambia)
function Revert-ShutdownTasks {
    Write-Host ">> Eliminando Tareas de Apagado Programado existentes..." -ForegroundColor Yellow
    try {
        schtasks /Delete /TN $TaskMañana /F -ErrorAction SilentlyContinue | Out-Null
        schtasks /Delete /TN $TaskTarde /F -ErrorAction SilentlyContinue | Out-Null
        schtasks /Delete /TN $TaskVespertino /F -ErrorAction SilentlyContinue | Out-Null
        Write-Host "   [OK] Tareas de apagado anteriores eliminadas." -ForegroundColor Green
    } catch {
        Write-Error "   [ERROR] Falló la eliminación de tareas: $_"
    }
}

# Función auxiliar para validar la hora
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

# Función principal de aplicación (V7)
function Apply-ShutdownTasks {
    Write-Host ">> Configurando Tareas de Apagado Programado (V7)..." -ForegroundColor Cyan
    
    # 1. Limpiar tareas anteriores
    Revert-ShutdownTasks
    Write-Host ""

    # 2. Definir el script de PowerShell que ejecutarán las tareas (sin cambios)
    $PayloadScriptString = @"
# --- Script de Apagado Progresivo ---
# T-10: Primer Aviso
$Msg10 = "AVISO (10 MIN): La notebook debe ser devuelta. Guarde su trabajo. Se apagará en 10 minutos."
msg * `$Msg10
Start-Sleep -Seconds 300 # Esperar 5 min
# T-5: Segundo Aviso
$Msg5 = "AVISO (5 MIN): Guarde su trabajo. El equipo se apagará en 5 minutos."
msg * `$Msg5
Start-Sleep -Seconds 240 # Esperar 4 min
# T-1: Aviso Final
$Msg1 = "AVISO FINAL (1 MIN): APAGADO INMINENTE. Cierre todo ahora."
msg * `$Msg1
Start-Sleep -Seconds 60 # Esperar 1 min
# T-0: Apagado
shutdown.exe /s /f /t 0
"@
    $EncodedPayload = [Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes($PayloadScriptString))
    $TaskRunCommand = "powershell.exe -WindowStyle Hidden -EncodedCommand $EncodedPayload"

    # 3. Definir límites de los turnos
    $Shifts = @{
        Mañana = @{ TaskName = $TaskMañana; Start = "07:35"; End = "12:15" }
        Tarde = @{ TaskName = $TaskTarde; Start = "12:25"; End = "17:05" }
        Vespertino = @{ TaskName = $TaskVespertino; Start = "17:15"; End = "21:40" }
    }

    Write-Host "Seleccione los turnos para configurar el apagado automático:"
    
    try {
        # --- Configuración Turno Mañana ---
        if ((Read-Host "   ¿Configurar Turno Mañana (07:35-12:15)? (s/n)") -eq 's') {
            $Shift = $Shifts.Mañana
            $ShutdownTime = Get-ValidatedTime "Mañana" $Shift.Start $Shift.End
            $TriggerTime = $ShutdownTime.Add([TimeSpan]::FromMinutes(-10)).ToString("hh\:mm")
            
            Write-Host "     -> Creando tarea '$($Shift.TaskName)' para disparar a las $TriggerTime (Apagado: $($ShutdownTime.ToString("hh\:mm")))"
            schtasks /Create /TN $Shift.TaskName /TR $TaskRunCommand /SC DAILY /ST $TriggerTime /RU "SYSTEM" /F /RL HIGHEST | Out-Null
        }

        # --- Configuración Turno Tarde ---
        if ((Read-Host "   ¿Configurar Turno Tarde (12:25-17:05)? (s/n)") -eq 's') {
            $Shift = $Shifts.Tarde
            $ShutdownTime = Get-ValidatedTime "Tarde" $Shift.Start $Shift.End
            $TriggerTime = $ShutdownTime.Add([TimeSpan]::FromMinutes(-10)).ToString("hh\:mm")

            Write-Host "     -> Creando tarea '$($Shift.TaskName)' para disparar a las $TriggerTime (Apagado: $($ShutdownTime.ToString("hh\:mm")))"
            schtasks /Create /TN $Shift.TaskName /TR $TaskRunCommand /SC DAILY /ST $TriggerTime /RU "SYSTEM" /F /RL HIGHEST | Out-Null
        }

        # --- Configuración Turno Vespertino ---
        if ((Read-Host "   ¿Configurar Turno Vespertino (17:15-21:40)? (s/n)") -eq 's') {
            $Shift = $Shifts.Vespertino
            $ShutdownTime = Get-ValidatedTime "Vespertino" $Shift.Start $Shift.End
            $TriggerTime = $ShutdownTime.Add([TimeSpan]::FromMinutes(-10)).ToString("hh\:mm")
            
            Write-Host "     -> Creando tarea '$($Shift.TaskName)' para disparar a las $TriggerTime (Apagado: $($ShutdownTime.ToString("hh\:mm")))"
            schtasks /Create /TN $Shift.TaskName /TR $TaskRunCommand /SC DAILY /ST $TriggerTime /RU "SYSTEM" /F /RL HIGHEST | Out-Null
        }
        
        Write-Host ""
        Write-Host "   [OK] Tareas de apagado configuradas." -ForegroundColor Green
    
    } catch {
        Write-Error "   [ERROR] Falló la creación de tareas programadas: $_"
    }
}

# =================================================================
# SECCIÓN 3: MENÚ INTERACTIVO PRINCIPAL
# =================================================================
Clear-Host
Write-Host "=================================================================" -ForegroundColor Cyan
Write-Host "      GESTIÓN DE ESTACIONES DE TRABAJO - ESCUELA (V7)"
Write-Host "=================================================================" -ForegroundColor Cyan
Write-Host "Seleccione una opción:"
Write-Host ""
Write-Host "   [1] Aplicar TODO (Autologon + Chrome + Tareas Apagado)" -ForegroundColor Green
Write-Host "   [2] Revertir TODO (Autologon + Chrome + Tareas Apagado)" -ForegroundColor Yellow
Write-Host "   -----------------------------------------------------"
Write-Host "   [3] Solo Aplicar Autologon"
Write-Host "   [44] Solo Revertir Autologon"
Write-Host "   -----------------------------------------------------"
Write-Host "   [5] Solo Aplicar Chrome (Perfiles Efímeros)"
Write-Host "   [6] Solo Revertir Chrome"
Write-Host "   -----------------------------------------------------"
Write-Host "   [7] Aplicar/Actualizar Tareas de Apagado (V7)" -ForegroundColor Magenta
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
    '7' { Apply-ShutdownTasks }   # Llama a la función V7
    '8' { Revert-ShutdownTasks }  # Llama a la función de borrado
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
Write-Host " - Tareas Apagado: Se ejecutarán solas en los horarios configurados."
Write-Host "================================================================="