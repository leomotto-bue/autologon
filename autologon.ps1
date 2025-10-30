# =================================================================
# Contenido para el archivo 'aplicar_logon.ps1' en GitHub
# Este script aplica la configuración de AutoAdminLogon
# Requiere ser ejecutado como Administrador.
# =================================================================

$KeyPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"

Write-Host "Iniciando la configuración de inicio de sesión automático..."

# Clave 1: DefaultUserName
# Establece el usuario predeterminado para el inicio de sesión.
Set-ItemProperty -Path $KeyPath -Name "DefaultUserName" -Value ".\\Alumno_Invitado" -Type String -Force
Write-Host "-> DefaultUserName configurado a .\\Alumno_Invitado"

# Clave 2: DefaultPassword
# Establece la contraseña predeterminada (cadena vacía).
# ¡Advertencia de seguridad! Esto expone una contraseña vacía en el registro.
Set-ItemProperty -Path $KeyPath -Name "DefaultPassword" -Value "" -Type String -Force
Write-Host "-> DefaultPassword configurado a cadena vacía"

# Clave 3: AutoAdminLogon
# Habilita el inicio de sesión automático.
Set-ItemProperty -Path $KeyPath -Name "AutoAdminLogon" -Value "1" -Type String -Force
Write-Host "-> AutoAdminLogon habilitado (1)"

Write-Host "Configuración completada. Los cambios serán efectivos después del reinicio."

# =================================================================
