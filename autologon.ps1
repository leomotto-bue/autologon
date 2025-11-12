<#
.SYNOPSIS
    Script INTERACTIVO MODULAR para configurar O revertir estaciones de trabajo.
    
.DESCRIPTION
    Permite seleccionar individualmente entre aplicar o revertir:
    - Configuración de AutoAdminLogon.
    - Directivas de Google Chrome (Perfiles efímeros).
    
    Requiere privilegios de Administrador.

.EXAMPLE
    (irm https://.../script.ps1) | iex

.NOTES
    Autor: Gemini
    Versión: 4.0
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
        } else {
            Write-Host "   -> No existen directivas de Chrome para revertir."
        }
    } catch { Write-Error "   [ERROR] Falló reversión Chrome: $_" }
}

# =================================================================
# SECCIÓN 3: MENÚ INTERACTIVO PRINCIPAL
# =================================================================
Clear-Host
Write-Host "=================================================================" -ForegroundColor Cyan
Write-Host "      GESTIÓN DE ESTACIONES DE TRABAJO - ESCUELA"
Write-Host "=================================================================" -ForegroundColor Cyan
Write-Host "Seleccione una opción:"
Write-Host ""
Write-Host "   [1] Aplicar TODO (Autologon + Chrome)" -ForegroundColor Green
Write-Host "   [2] Revertir TODO (Autologon + Chrome)" -ForegroundColor Yellow
Write-Host "   ---------------------------------------"
Write-Host "   [3] Solo Aplicar Autologon"
Write-Host "   [4] Solo Revertir Autologon"
Write-Host "   ---------------------------------------"
Write-Host "   [5] Solo Aplicar Chrome (Perfiles Efímeros)"
Write-Host "   [6] Solo Revertir Chrome"
Write-Host "   ---------------------------------------"
Write-Host "   [Q] Salir"
Write-Host ""

$choice = Read-Host "Su elección"

# =================================================================
# SECCIÓN 4: LÓGICA DE EJECUCIÓN
# =================================================================
Write-Host ""
switch ($choice) {
    '1' { Apply-AutoLogon; Write-Host ""; Apply-Chrome }
    '2' { Revert-AutoLogon; Write-Host ""; Revert-Chrome }
    '3' { Apply-AutoLogon }
    '4' { Revert-AutoLogon }
    '5' { Apply-Chrome }
    '6' { Revert-Chrome }
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
Write-Host "================================================================="
