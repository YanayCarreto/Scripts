#!/bin/bash
export PATH=$PATH:/usr/sbin
#Scrip v1

[ "$EUID" -ne 0 ] && echo "Ejecuta con sudo." && exit 1

# Detección del sistema de archivos que tiene cuotas
detectar_home_con_cuotas() {
    # Busca el punto de montaje de cualquier sistema de archivos con cuotas activas
    local mount_point
    mount_point=$(findmnt -lno TARGET --options usrquota,grpquota | head -n1)
    if [ -n "$mount_point" ]; then
        echo "$mount_point"
        return 0
    else
        echo "/home"
        return 1
    fi
}

# Reglas de la ontraseña
validar_pass() {
    local p="$1"
    [ ${#p} -lt 8 ] && echo "Debe tener al menos 8 caracteres." && return 1
    ! grep -q "[A-Z]" <<< "$p" && echo "Falta una mayúscula." && return 1
    ! grep -q "[a-z]" <<< "$p" && echo "Falta una minúscula." && return 1
    ! grep -q "[0-9]" <<< "$p" && echo "Falta un número." && return 1
    ! grep -q "[!@#$%^&*()_+]" <<< "$p" && echo "Falta un carácter especial (!@#$%^&*()_+)." && return 1
    return 0
}


# Función para asignar cuotas

asignar_cuota() {
    local usuario="$1"
    local home_base="$2"
    local soft hard

    # Verificar si el sistema de archivos realmente tiene cuotas activas
    if ! quotaon -p "$home_base" &>/dev/null; then
        echo "Aviso: El sistema de archivos $home_base no tiene cuotas activas. No se aplicarán cuotas."
        return 0
    fi

    read -p "¿Asignar cuota a $usuario? (s/N): " resp
    if [[ "$resp" =~ ^[sSyY] ]]; then
        read -p "Límite soft en MB: " soft_mb
        read -p "Límite hard en MB: " hard_mb
        soft=$((soft_mb * 1024))
        hard=$((hard_mb * 1024))
    else
        return 0
    fi

    if setquota -u "$usuario" "$soft" "$hard" 0 0 "$home_base"; then
        echo "Cuota asignada: soft=$((soft/1024)) MB, hard=$((hard/1024)) MB"
    else
        echo "ERROR: No se pudo asignar la cuota."
    fi
}

# Configuración automática del entorno

BASE_HOME=$(detectar_home_con_cuotas)
HAY_CUOTAS=$?

if [ "$HAY_CUOTAS" -eq 1 ]; then
    echo "No se detectaron cuotas activas en el sistema."
    echo "   Se usará $BASE_HOME como directorio base (sin cuotas)."
else
    echo " Sistema de archivos con cuotas detectado en: $BASE_HOME"
fi

# Entrada de datos del nuevo usuario

read -p "Nombre de usuario: " USUARIO
if id "$USUARIO" &>/dev/null; then
    echo "El usuario '$USUARIO' ya existe. Saliendo."
    exit 1
fi

read -p "Nombre completo (opcional): " NOMBRE_COMPLETO

read -p "Directorio home (por defecto $BASE_HOME/$USUARIO): " DIR_HOME
DIR_HOME=${DIR_HOME:-$BASE_HOME/$USUARIO}

read -p "Shell (por defecto /bin/bash): " SHELL_USER
SHELL_USER=${SHELL_USER:-/bin/bash}

# Contraseña segura
echo "La contraseña debe tener: 8+ caracteres, mayúscula, minúscula, número y especial (!@#$%^&*()_+)"
while true; do
    read -s -p "Contraseña: " CONTRASENA1; echo
    read -s -p "Confirmar contraseña: " CONTRASENA2; echo
    [ "$CONTRASENA1" != "$CONTRASENA2" ] && echo "No coinciden." && continue
    validar_pass "$CONTRASENA1" && break
done

# Crear usuario
useradd -c "$NOMBRE_COMPLETO" -d "$DIR_HOME" -s "$SHELL_USER" -m "$USUARIO"
echo "$USUARIO:$CONTRASENA1" | chpasswd

read -p "¿Forzar cambio de contraseña en el primer login? (s/N): " FORZAR
[[ "$FORZAR" =~ ^[sSyY] ]] && chage -d 0 "$USUARIO"


# Asignar cuota si corresponde
if [ "$HAY_CUOTAS" -eq 0 ] && [[ "$DIR_HOME" == "$BASE_HOME"* ]]; then
    asignar_cuota "$USUARIO" "$BASE_HOME"
else
    echo "No se aplican cuotas ya que no hay sistema que cuente con ellas."
fi


# Configuración del periodo de gracia
if [ "$HAY_CUOTAS" -eq 0 ] && quotaon -p "$BASE_HOME" &>/dev/null && [[ "$DIR_HOME" == "$BASE_HOME"* ]]; then
    read -p "¿Quieres configurar el período de gracia para el usuario '$USUARIO'? (s/n): " config_gracia
    if [[ "$config_gracia" == "s" || "$config_gracia" == "S" ]]; then
        if command -v edquota &>/dev/null; then
            echo "Abriendo el editor para configurar el período de gracia de $USUARIO..."
            echo "En el editor, busca la línea 'grace:' y cambia los valores (ejemplo: 7days, 1hora, etc)"
            read -p "Presiona Enter para continuar..."
            edquota -T "$USUARIO"
            echo "Período de gracia para $USUARIO actualizado (si se realizaron cambios)."
        else
            echo "El comando 'edquota' no está disponible. Instala el paquete 'quota'."
        fi
    fi
fi
echo "Usuario '$USUARIO' creado exitosamente."
