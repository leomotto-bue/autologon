<#
.SYNOPSIS
    Script INTERACTIVO para configurar O revertir estaciones de trabajo de escuela.
    
.DESCRIPTION
    Este script se ejecuta, comprueba los permisos de administrador y LUEGO
    muestra un menú para elegir la acción a realizar:
    
    1. Aplicar configuraciones (Autologon + Chrome).
    2. Revertir configuraciones.
    3. Salir.
    
    Requiere privilegios de Administrador para CUALQUIER acción de cambio.

.EXAMPLE
    (irm https://.../script.ps1) | iex
    (A continuación, aparecerá un menú pidiendo elegir 1, 2 o 3)

.NOTES
    Autor: Gemini
    Versión: 3.0
#>

# =================================================================
# SECCIÓN 1: VERIFICACIÓN DE ADMINISTRADOR
# =================================================================
Write-Host "Verificando privilegios de Administrador..." -ForegroundColor Yellow

if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Error "ACCESO DENEGADO: Este script debe ejecutarse como Administrador."
    Write-Warning "Por favor, reinicie su terminal de PowerShell (o CMD) como 'Administrador' e intente de nuevo."
    
    if ($Host.Name -eq "ConsoleHost") {
        Read-Host "Presione Enter para salir..."
    }
    # Salir del script si no es admin
    exit 1
}

Write-Host "Privilegios de Administrador confirmados." -ForegroundColor Green
Write-Host ""

# =================================================================
# SECCIÓN 2: DEFINICIÓN DE VARIABLES Y FUNCIONES
# =================================================================

# --- Variables Globales de Rutas ---
$KeyPathAutoLogon = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"
$ChromePolicyPath = "HKLM:\SOFTWARE\Policies\Google\Chrome"
$ChromePolicyParentPath = "HKLM:\SOFTWARE\Policies\Google"

# --- FUNCIÓN: APLICAR CONFIGURACIONES ---
function Apply-SchoolPolicies {
    Write-Host "=================================================================" -ForegroundColor Cyan
    Write-Host " Iniciando APLICACIÓN de configuraciones de escuela..."
    Write-Host "=================================================================" -ForegroundColor Cyan

    # --- Aplicar Autologon ---
    Write-Host "Aplicando configuración de Autologon..."
    try {
        Set-ItemProperty -Path $KeyPathAutoLogon -Name "DefaultUserName" -Value ".\Alumno_Invitado" -Type String -Force
        Write-Host "-> DefaultUserName configurado a '.\Alumno_Invitado'"

        Set-ItemProperty -Path $KeyPathAutoLogon -Name "DefaultPassword" -Value "" -Type String -Force
        Write-Host "-> DefaultPassword configurado a cadena vacía (¡Advertencia de seguridad!)"

        Set-ItemProperty -Path $KeyPathAutoLogon -Name "AutoAdminLogon" -Value "1" -Type String -Force
        Write-Host "-> AutoAdminLogon habilitado (1)"
        
        Write-Host "Configuración de Autologon APLICADA." -ForegroundColor Green
    }
    catch {
        Write-Error "Falló la configuración de Autologon: $_"
    }

    # --- Aplicar Directivas de Chrome ---
    Write-Host ""
    Write-Host "Aplicando directivas de Google Chrome..."
    try {
        if (-not (Test-Path $ChromePolicyPath)) {
            Write-Host "-> La ruta de directivas de Chrome no existe. Creándola ahora..."
            New-Item -Path $ChromePolicyParentPath -Name "Chrome" -Force -ErrorAction Stop | Out-Null
        }
        
        Set-ItemProperty -Path $ChromePolicyPath -Name "ForceEphemeralProfiles" -Value 1 -Type DWord -Force -ErrorAction Stop
        Write-Host "-> ForceEphemeralProfiles configurado a 1 (Perfiles temporales)"

        Set-ItemProperty -Path $ChromePolicyPath -Name "SyncDisabled" -Value 1 -Type DWord -Force -ErrorAction Stop
        Write-Host "-> SyncDisabled configurado a 1 (Sincronización deshabilitada)"

        Set-ItemProperty -Path $ChromePolicyPath -Name "BrowserSignin" -Value 0 -Type DWord -Force -ErrorAction Stop
        Write-Host "-> BrowserSignin configurado a 0 (Inicio de sesión en navegador deshabilitado)"

        Write-Host "Directivas de Chrome APLICADAS." -ForegroundColor Green
    }
    catch {
        Write-Error "Falló la configuración de directivas de Chrome: $_"
    }
}

# --- FUNCIÓN: REVERTIR CONFIGURACIONES ---
function Revert-SchoolPolicies {
    Write-Host "=================================================================" -ForegroundColor Yellow
    Write-Host " Iniciando REVERSIÓN de configuraciones de escuela..."
    Write-Host "=================================================================" -ForegroundColor Yellow

    # --- Revertir Autologon ---
    Write-Host "Revirtiendo configuración de Autologon..."
    try {
        Set-ItemProperty -Path $KeyPathAutoLogon -Name "AutoAdminLogon" -Value "0" -Type String -Force
        Write-Host "-> AutoAdminLogon deshabilitado (0)"

        Remove-ItemProperty -Path $KeyPathAutoLogon -Name "DefaultUserName" -ErrorAction SilentlyContinue
        Write-Host "-> DefaultUserName eliminado."
        
        Remove-ItemProperty -Path $KeyPathAutoLogon -Name "DefaultPassword" -ErrorAction SilentlyContinue
        Write-Host "-> DefaultPassword eliminado."

        Write-Host "Configuración de Autologon REVERTIDA." -ForegroundColor Green
    }
    catch {
        Write-Error "Falló la reversión de Autologon: $_"
    }

    # --- Revertir Directivas de Chrome ---
    Write-Host ""
    Write-Host "Revirtiendo directivas de Google Chrome..."
    try {
        if (Test-Path $ChromePolicyPath) {
            Remove-ItemProperty -Path $ChromePolicyPath -Name "ForceEphemeralProfiles" -ErrorAction SilentlyContinue
            Write-Host "-> Directiva 'ForceEphemeralProfiles' eliminada."
            
            Remove-ItemProperty -Path $ChromePolicyPath -Name "SyncDisabled" -ErrorAction SilentlyContinue
            Write-Host "-> Directiva 'SyncDisabled' eliminada."
            
            Remove-ItemProperty -Path $ChromePolicyPath -Name "BrowserSignin" -ErrorAction SilentlyContinue
            Write-Host "-> Directiva 'BrowserSignin' eliminada."
            
            Write-Host "Directivas de Chrome REVERTIDAS." -ForegroundColor Green
        } else {
            Write-Host "-> La ruta de directivas de Chrome no existe, no hay nada que revertir."
        }
    }
    catch {
        Write-Error "Falló la reversión de directivas de Chrome: $_"
    }
}

# =================================================================
# SECCIÓN 3: MENÚ INTERACTIVO (NUEVO)
# =================================================================
Write-Host ""
Write-Host "=================================================================" -ForegroundColor Cyan
Write-Host " MENÚ DE ACCIONES - CONFIGURACIÓN DE ESTACIONES"
Write-Host "================================================================="
Write-Host "Por favor, elija la acción que desea realizar:"
Write-Host ""
Write-Host "   [1] Aplicar configuraciones de escuela (Autologon + Chrome)" -ForegroundColor Green
Write-Host "   [2] Revertir configuraciones de escuela" -ForegroundColor Yellow
Write-Host "   [3] Salir sin hacer cambios" -ForegroundColor Gray
Write-Host ""

$choice = Read-Host "Escriba su opción (1, 2, o 3) y presione Enter"

# =================================================================
# SECCIÓN 4: EJECUCIÓN PRINCIPAL (LÓGICA DE SWITCH)
# =================================================================
$actionTaken = $false

switch ($choice) {
    '1' {
        Write-Host ""
        Write-Host "Ha seleccionado: APLICAR." -ForegroundColor Green
        Apply-SchoolPolicies
        $actionTaken = $true
    }
    '2' {
        Write-Host ""
        Write-Host "Ha seleccionado: REVERTIR." -ForegroundColor Yellow
        Revert-SchoolPolicies
        $actionTaken = $true
    }
    '3' {
        Write-Host ""
        Write-Host "Ha seleccionado: Salir." -ForegroundColor Gray
        Write-Host "No se han realizado cambios."
    }
    default {
        Write-Host ""
        Write-Warning "Opción no válida: '$choice'."
        Write-Warning "Saliendo del script. No se han realizado cambios."
    }
}

# =D================================================================
# FIN: MENSAJE DE FINALIZACIÓN
# =================================================================
Write-Host ""
Write-Host "=================================================================" -ForegroundColor Green
Write-Host "Script finalizado."
if ($actionTaken) {
    Write-Host "Los cambios de registro han sido procesados."
    Write-Host "Recuerde reiniciar el sistema (para Autologon) o Google Chrome (para directivas) si es necesario."
} else {
    Write-Host "No se aplicaron cambios en el registro."
}
Write-Host "================================================================="
