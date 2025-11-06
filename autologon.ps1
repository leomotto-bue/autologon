<#
.SYNOPSIS
    Script unificado para configurar O revertir estaciones de trabajo de escuela.
    
.DESCRIPTION
    Este script acepta un parámetro -Action para 'apply' (aplicar) o 'revert' (revertir)
    las siguientes configuraciones:
    
    1. Configuración de AutoAdminLogon para un usuario invitado.
    2. Directivas de Google Chrome para forzar perfiles efímeros y deshabilitar sincronización.
    
    Requiere privilegios de Administrador para CUALQUIER acción.

.PARAMETER Action
    [string] Obligatorio. Especifica la acción a realizar.
    Valores válidos:
    - 'apply'  : Aplica todas las configuraciones de la escuela.
    - 'revert' : Revierte todas las configuraciones a un estado predeterminado.

.EXAMPLE
    (irm https://.../script.ps1) | iex -Action apply
    
.EXAMPLE
    (irm https://.../script.ps1) | iex -Action revert

.NOTES
    Autor: Gemini
    Versión: 2.0
#>

# =================================================================
# INICIO: DEFINICIÓN DE PARÁMETROS
# =================================================================
param(
    [Parameter(Mandatory=$true, HelpMessage="Indica la acción a realizar: 'apply' (aplicar) o 'revert' (revertir).")]
    [ValidateSet('apply', 'revert')]
    [string]$Action
)

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
    exit 1
}

Write-Host "Privilegios de Administrador confirmados." -ForegroundColor Green
Write-Host "Acción seleccionada: $Action" -ForegroundColor Cyan
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
        # Asegurarse de que la ruta de la clave del registro exista
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
        # Deshabilitar Autologon
        Set-ItemProperty -Path $KeyPathAutoLogon -Name "AutoAdminLogon" -Value "0" -Type String -Force
        Write-Host "-> AutoAdminLogon deshabilitado (0)"

        # Eliminar las credenciales almacenadas (importante por seguridad)
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
            # Eliminar las directivas específicas que configuramos
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
# SECCIÓN 3: EJECUCIÓN PRINCIPAL (LÓGICA DE SWITCH)
# =================================================================

switch ($Action) {
    'apply' {
        Apply-SchoolPolicies
    }
    'revert' {
        Revert-SchoolPolicies
    }
    # Esta sección 'default' técnicamente no es necesaria gracias a ValidateSet,
    # pero es una buena práctica en caso de que el script se modifique.
    default {
        Write-Error "Acción '$Action' no reconocida."
    }
}

# =================================================================
# FIN: MENSAJE DE FINALIZACIÓN
# =================================================================
Write-Host ""
Write-Host "=================================================================" -ForegroundColor Green
Write-Host "¡Script completado!"
Write-Host "Acción realizada: $Action"
Write-Host "Los cambios de registro han sido aplicados."
Write-Host "Recuerde reiniciar el sistema (para Autologon) o Google Chrome (para directivas) si es necesario."
Write-Host "================================================================="
