#!/bin/bash

[ "$EUID" -ne 0 ] && echo "Ejecuta con sudo." && exit 1

# Validar contraseña (reglas fijas: mínimo 8, mayúscula, minúscula, número, especial)
validar_pass() {
    local p="$1"
    [ ${#p} -lt 8 ] && echo "Debe tener al menos 8 caracteres." && return 1
    ! grep -q "[A-Z]" <<< "$p" && echo "Falta una mayúscula." && return 1
    ! grep -q "[a-z]" <<< "$p" && echo "Falta una minúscula." && return 1
    ! grep -q "[0-9]" <<< "$p" && echo "Falta un número." && return 1
    ! grep -q "[!@#$%^&*()_+]" <<< "$p" && echo "Falta un carácter especial (!@#$%^&*()_+)." && return 1
    return 0
}

# Preguntar datos
read -p "Nombre de usuario: " USUARIO
id "$USUARIO" &>/dev/null && echo "El usuario ya existe." && exit 1

read -p "Nombre completo (opcional): " NOMBRE_COMPLETO
read -p "Directorio home (por defecto /home/$USUARIO): " DIR_HOME
DIR_HOME=${DIR_HOME:-/home/$USUARIO}
read -p "Shell (por defecto /bin/bash): " SHELL_USER
SHELL_USER=${SHELL_USER:-/bin/bash}

# Contraseña con confirmación y validación
echo "La contraseña debe tener: 8+ caracteres, mayúscula, minúscula, número y especial (!@#$%^&*()_+)"
while true; do
    read -s -p "Contraseña: " CONTRASENA1; echo
    read -s -p "Confirmar: " CONTRASENA2; echo
    [ "$CONTRASENA1" != "$CONTRASENA2" ] && echo "No coinciden." && continue
    validar_pass "$CONTRASENA1" && break
done

# Crear usuario
useradd -c "$NOMBRE_COMPLETO" -d "$DIR_HOME" -s "$SHELL_USER" -m "$USUARIO"
echo "$USUARIO:$CONTRASENA1" | chpasswd

# Forzar cambio de contraseña en primer login
read -p "¿Forzar cambio en primer login? (s/N): " FORZAR
[[ "$FORZAR" =~ ^[sSyY] ]] && chage -d 0 "$USUARIO"

echo "Usuario $USUARIO creado."
