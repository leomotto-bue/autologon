<#
.SYNOPSIS
    Script unificado para configurar estaciones de trabajo de escuela.
    1. Configura el AutoAdminLogon para un usuario invitado.
    2. Aplica directivas de Google Chrome para forzar perfiles efímeros
       y deshabilitar la sincronización de cuentas.

.DESCRIPTION
    Este script modifica el registro de Windows (HKLM) y requiere
    privilegios de Administrador para ejecutarse.
    
    Está diseñado para ser ejecutado mediante 'irm | iex' en un entorno
    de configuración.

.NOTES
    Autor: Gemini
    Versión: 1.0
#>

# =================================================================
# INICIO: VERIFICACIÓN DE ADMINISTRADOR
# =================================================================
Write-Host "Verificando privilegios de Administrador..." -ForegroundColor Yellow

if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Error "ACCESO DENEGADO: Este script debe ejecutarse como Administrador."
    Write-Warning "Por favor, reinicie su terminal de PowerShell (o CMD) como 'Administrador' e intente de nuevo."
    
    # Pausa para que el usuario pueda leer el error si se ejecuta interactivamente
    if ($Host.Name -eq "ConsoleHost") {
        Read-Host "Presione Enter para salir..."
    }
    # Termina el script si no es admin
    exit 1
}

Write-Host "Privilegios de Administrador confirmados." -ForegroundColor Green


# =================================================================
# SECCIÓN 1: CONFIGURACIÓN DE AUTOLOGON
# =================================================================
Write-Host ""
Write-Host "=================================================================" -ForegroundColor Cyan
Write-Host " Iniciando la configuración de inicio de sesión automático..."
Write-Host "=================================================================" -ForegroundColor Cyan

$KeyPathAutoLogon = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"

try {
    # Clave 1: DefaultUserName
    Set-ItemProperty -Path $KeyPathAutoLogon -Name "DefaultUserName" -Value ".\Alumno_Invitado" -Type String -Force
    Write-Host "-> DefaultUserName configurado a '.\Alumno_Invitado'"

    # Clave 2: DefaultPassword
    # ¡Advertencia de seguridad! Esto expone una contraseña vacía en el registro.
    Set-ItemProperty -Path $KeyPathAutoLogon -Name "DefaultPassword" -Value "" -Type String -Force
    Write-Host "-> DefaultPassword configurado a cadena vacía"

    # Clave 3: AutoAdminLogon
    Set-ItemProperty -Path $KeyPathAutoLogon -Name "AutoAdminLogon" -Value "1" -Type String -Force
    Write-Host "-> AutoAdminLogon habilitado (1)"

    Write-Host "Configuración de Autologon completada." -ForegroundColor Green
}
catch {
    Write-Error "Falló la configuración de Autologon: $_"
}


# =================================================================
# SECCIÓN 2: DIRECTIVAS DE GOOGLE CHROME (SIN .REG)
# =================================================================
Write-Host ""
Write-Host "=================================================================" -ForegroundColor Cyan
Write-Host " Iniciando la configuración de directivas de Google Chrome..."
Write-Host "=================================================================" -ForegroundColor Cyan

$ChromePolicyPath = "HKLM:\SOFTWARE\Policies\Google\Chrome"

try {
    # Paso 1: Asegurarse de que la ruta de la clave del registro exista
    if (-not (Test-Path $ChromePolicyPath)) {
        Write-Host "La ruta de directivas de Chrome no existe. Creándola ahora..."
        New-Item -Path "HKLM:\SOFTWARE\Policies\Google" -Name "Chrome" -Force | Out-Null
    } else {
        Write-Host "La ruta de directivas de Chrome ya existe."
    }

    # Paso 2: Aplicar las directivas de Chrome
    
    # Directiva 1: ForceEphemeralProfiles (DWORD = 1)
    # Fuerza a que los perfiles sean temporales. Se borran al cerrar Chrome.
    Set-ItemProperty -Path $ChromePolicyPath -Name "ForceEphemeralProfiles" -Value 1 -Type DWord -Force
    Write-Host "-> ForceEphemeralProfiles configurado a 1 (Perfiles temporales habilitados)"

    # Directiva 2: SyncDisabled (DWORD = 1)
    # Deshabilita completamente la función de sincronización de Chrome.
    Set-ItemProperty -Path $ChromePolicyPath -Name "SyncDisabled" -Value 1 -Type DWord -Force
    Write-Host "-> SyncDisabled configurado a 1 (Sincronización deshabilitada)"

    # Directiva 3: BrowserSignin (DWORD = 0)
    # Evita que los usuarios inicien sesión en el navegador (política complementaria).
    Set-ItemProperty -Path $ChromePolicyPath -Name "BrowserSignin" -Value 0 -Type DWord -Force
    Write-Host "-> BrowserSignin configurado a 0 (Inicio de sesión en navegador deshabilitado)"

    Write-Host "Configuración de directivas de Chrome completada." -ForegroundColor Green
}
catch {
    Write-Error "Falló la configuración de directivas de Chrome: $_"
}


# =================================================================
# FIN: MENSAJE DE FINALIZACIÓN
# =================================================================
Write-Host ""
Write-Host "=================================================================" -ForegroundColor Green
Write-Host "¡Script completado!"
Write-Host "Los cambios de Autologon y Google Chrome han sido aplicados."
Write-Host "Autologon: Requiere un reinicio del sistema."
Write-Host "Chrome: Requiere un reinicio de Google Chrome (si estaba abierto)."
Write-Host "================================================================="
