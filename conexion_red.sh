#!/bin/bash
#Script que debe:
# -MOstrar las interfaces de red disponibles y su estado
# -Cambiar el estado de la interfaz
# -Conectarse a la red con la interfaz cableada o inálambrica
# -Seleccionar si la configuración de la red será  estática o dinámica
# -Guardar la configuración  y hacerla permanente
# -Mostar las redes inalámbricas disponibles y establecer conexión sin importar el tipo de cifrado que use la red

# Verificar ejecución como root
if [[ $EUID -ne 0 ]]; then
    echo "Este script debe ejecutarse como root."
    exit 1
fi

# Lista de herramientas necesarias
herramientas=("ip" "ifconfig" "route" "iw" "iwlist" "wpa_passphrase" "wpa_supplicant" "dhclient")
faltantes=()

# Verificar cada herramienta
for cmd in "${herramientas[@]}"; do
    if ! command -v $cmd &>/dev/null; then
        faltantes+=($cmd)
    fi
done

# Si faltan herramientas, mostrar mensaje y salir
if [[ ${#faltantes[@]} -gt 0 ]]; then
    echo "ERROR: Faltan las siguientes herramientas: ${faltantes[*]}"
    echo "Por favor, instala los paquetes necesarios"
    exit 1
fi

# Función para mostrar el menú principal
mostrar_menu() {
    clear
    echo "Conexión a Red"
    echo ""
    echo "1. Mostrar interfaces disponibles y estado"
    echo "2. Activar/Desactivar una interfaz"
    echo "3. Conexión cableada (DHCP)"
    echo "4. Conexión cableada (IP estática)"
    echo "5. Hacer permanente la configuración cableada actual"
    echo "6. Conexión Wi-Fi"
    echo "7. Hacer permanente la configuración Wi-Fi actual"
    echo "8. Salir"
    read -p "Selecciona una opción [1-8]: " opcion
}

# 1. Mostrar interfaces
mostrar_interfaces() {
    echo ""
    echo "-Interfaces de red disponibles"
    ip link show | awk -F': ' '/^[0-9]+:/ {print $2}' | grep -v lo
    echo ""
    echo "-Direcciones IP"
    ip addr show | grep -E '^[0-9]+:|inet '
    read -p "Presiona Enter para continuar."
}

# 2. Cambiar estado de interfaz
cambiar_estado() {
    echo ""
    echo "Interfaces disponibles:"
    ip link show | awk -F': ' '/^[0-9]+:/ {print $2}' | grep -v lo
    read -p "Nombre de la interfaz (ej: eth0, wlan0, enp0): " iface
    if ! ip link show "$iface" &>/dev/null; then
        echo "La interfaz $iface no existe."
        read -p "Presiona Enter."
        return
    fi
    estado=$(ip link show "$iface" | grep -o "state [^ ]*" | cut -d' ' -f2)
    echo "Estado actual: $estado"
    read -p "¿Quieres (U)p o (D)own? " accion
    case $accion in
        u|U)
            ip link set "$iface" up
            echo "Interfaz $iface activada."
            ;;
        d|D)
            ip link set "$iface" down
            echo "Interfaz $iface desactivada."
            ;;
        *)
            echo "Opción no válida."
            ;;
    esac
    read -p "Presiona Enter."
}

# 3. Conexión cableada temporal DHCP
cable_dhcp_temporal() {
    echo ""
    echo "Interfaces cableadas disponibles:"
    ip link show | awk -F': ' '/^[0-9]+:/ {print $2}' | grep -E '^e|^en'
    read -p "Nombre de la interfaz (ej: eth0): " iface
    if ! ip link show "$iface" &>/dev/null; then
        echo "La interfaz $iface no existe."
        read -p "Presiona Enter."
        return
    fi
    ip link set "$iface" up
    echo "Obteniendo IP por DHCP."
    dhclient -v "$iface"
    echo "Conexión DHCP temporal establecida."
    read -p "Presiona Enter."
}

# 4. Conexión cableada temporal estática
cable_estatica_temporal() {
    echo ""
    echo "Interfaces cableadas disponibles:"
    ip link show | awk -F': ' '/^[0-9]+:/ {print $2}' | grep -E '^e|^en'
    read -p "Nombre de la interfaz (ej: eth0): " iface
    if ! ip link show "$iface" &>/dev/null; then
        echo "La interfaz $iface no existe."
        read -p "Presiona Enter."
        return
    fi
    read -p "Dirección IP con máscara (ej: 192.168.1.100/24): " ip
    read -p "Puerta de enlace (ej: 192.168.1.1): " gateway
    read -p "DNS (separados por espacios, ej: 8.8.8.8 8.8.4.4): " dns_servers
    ip addr flush dev "$iface"
    ip addr add "$ip" dev "$iface"
    ip link set "$iface" up
    ip route del default &>/dev/null
    ip route add default via "$gateway" dev "$iface"
    > /etc/resolv.conf
    for dns in $dns_servers; do
        echo "nameserver $dns" >> /etc/resolv.conf
    done
    echo "Conexión estática temporal establecida."
    read -p "Presiona Enter."
}

# 5. Hacer permanente la configuración cableada actual
hacer_permanente_cable() {
    echo ""
    echo "Hacer permanente la configuración actual de una interfaz cableada"
    ip link show | awk -F': ' '/^[0-9]+:/ {print $2}' | grep -E '^e|^en'
    read -p "Nombre de la interfaz (ej: eth0): " iface
    if ! ip link show "$iface" &>/dev/null; then
        echo "La interfaz $iface no existe."
        read -p "Presiona Enter."
        return
    fi
    ip_addr=$(ip -4 addr show "$iface" | grep inet | awk '{print $2}' | head -1)
    gateway=$(ip route show default dev "$iface" | awk '{print $3}')
    dns_list=$(grep nameserver /etc/resolv.conf | awk '{print $2}' | tr '\n' ' ')
    if [[ -z "$ip_addr" ]]; then
        echo "No hay dirección IP asignada en $iface. Configura primero una conexión temporal."
        read -p "Presiona Enter."
        return
    fi
    echo "Configuración actual detectada:"
    echo "  IP: $ip_addr"
    echo "  Gateway: ${gateway:-ninguna}"
    echo "  DNS: ${dns_list:-ninguno}"
    read -p "¿Es esta configuración DHCP (d) o estática (e)? " tipo
    cp /etc/network/interfaces /etc/network/interfaces.backup.$(date +%Y%m%d%H%M%S)
    sed -i "/iface $iface inet/d" /etc/network/interfaces
    sed -i "/auto $iface/d" /etc/network/interfaces
    echo "auto $iface" >> /etc/network/interfaces
    if [[ $tipo =~ ^[dD]$ ]]; then
        echo "iface $iface inet dhcp" >> /etc/network/interfaces
        echo "Configuración DHCP guardada permanentemente."
    else
        ip_sin_cidr=$(echo $ip_addr | cut -d/ -f1)
        cidr=$(echo $ip_addr | cut -d/ -f2)
        case $cidr in
            8) mask="255.0.0.0" ;;
            16) mask="255.255.0.0" ;;
            24) mask="255.255.255.0" ;;
            *) mask="255.255.255.0" ;;
        esac
        echo "iface $iface inet static" >> /etc/network/interfaces
        echo "    address $ip_sin_cidr" >> /etc/network/interfaces
        echo "    netmask $mask" >> /etc/network/interfaces
        if [[ -n "$gateway" ]]; then
            echo "    gateway $gateway" >> /etc/network/interfaces
        fi
        if [[ -n "$dns_list" ]]; then
            echo "    dns-nameservers $dns_list" >> /etc/network/interfaces
        fi
        echo "Configuración estática guardada permanentemente."
    fi
    ifdown "$iface" 2>/dev/null && ifup "$iface"
    echo "Configuración aplicada."
    read -p "Presiona Enter."
}

# 6. Conexión Wi-Fi temporal
wifi_temporal() {
    echo ""
    echo "Interfaces Wi-Fi disponibles:"
    iwconfig 2>/dev/null | grep -o "^[^ ]*" | grep -v lo | grep -v "no wireless"
    read -p "Nombre de la interfaz Wi-Fi (ej: wlan0): " iface
    if ! iwconfig "$iface" &>/dev/null; then
        echo "Interfaz no válida o no soporta Wi-Fi."
        read -p "Presiona Enter."
        return
    fi
    ip link set "$iface" up
    echo "Escaneando redes Wi-Fi."
    iwlist "$iface" scan | grep -E "ESSID|Encryption|Quality" | sed 's/^[[:space:]]*//'
    read -p "SSID de la red a la que deseas conectarte: " ssid
    read -p "¿La red tiene contraseña? (s/n): " secured
    if [[ $secured =~ ^[Ss]$ ]]; then
        read -s -p "Contraseña: " pass
        echo
        wpa_passphrase "$ssid" "$pass" > /tmp/wpa_$iface.conf
    else
        cat > /tmp/wpa_$iface.conf <<EOF
network={
    ssid="$ssid"
    key_mgmt=NONE
}
EOF
    fi
    killall wpa_supplicant 2>/dev/null
    wpa_supplicant -B -i "$iface" -c /tmp/wpa_$iface.conf
    echo "Obteniendo IP por DHCP."
    dhclient -v "$iface"
    echo "Conexión Wi-Fi temporal establecida."
    read -p "Presiona Enter."
}

# 7. Hacer permanente la configuración Wi-Fi actual
hacer_permanente_wifi() {
    echo ""
    echo "Hacer permanente la configuración Wi-Fi actual"
    iwconfig 2>/dev/null | grep -o "^[^ ]*" | grep -v lo | grep -v "no wireless"
    read -p "Nombre de la interfaz Wi-Fi (ej: wlan0): " iface
    if ! iwconfig "$iface" &>/dev/null; then
        echo "Interfaz no válida."
        read -p "Presiona Enter."
        return
    fi
    if ! pgrep -f "wpa_supplicant.*$iface" > /dev/null; then
        echo "No hay una conexión Wi-Fi activa en $iface. Conéctate temporalmente primero (opción 6)."
        read -p "Presiona Enter..."
        return
    fi
    read -p "SSID de la red a la que estás conectado: " ssid
    read -p "¿La red tiene contraseña? (s/n): " secured
    mkdir -p /etc/wpa_supplicant
    conf_file="/etc/wpa_supplicant/wpa_supplicant-$iface.conf"
    if [[ $secured =~ ^[Ss]$ ]]; then
        read -s -p "Contraseña: " pass
        echo
        wpa_passphrase "$ssid" "$pass" > "$conf_file"
    else
        cat > "$conf_file" <<EOF
network={
    ssid="$ssid"
    key_mgmt=NONE
}
EOF
    fi
    chmod 600 "$conf_file"
    cp /etc/network/interfaces /etc/network/interfaces.backup.$(date +%Y%m%d%H%M%S)
    sed -i "/iface $iface inet/d" /etc/network/interfaces
    sed -i "/auto $iface/d" /etc/network/interfaces
    echo "auto $iface" >> /etc/network/interfaces
    echo "iface $iface inet dhcp" >> /etc/network/interfaces
    echo "    wpa-conf $conf_file" >> /etc/network/interfaces
    ifdown "$iface" 2>/dev/null && ifup "$iface"
    echo "Configuración Wi-Fi permanente guardada."
    read -p "Presiona Enter."
}

# Bucle principal
while true; do
    mostrar_menu
    case $opcion in
        1) mostrar_interfaces ;;
        2) cambiar_estado ;;
        3) cable_dhcp_temporal ;;
        4) cable_estatica_temporal ;;
        5) hacer_permanente_cable ;;
        6) wifi_temporal ;;
        7) hacer_permanente_wifi ;;
        8) echo "Saliendo..."; exit 0 ;;
        *) echo "Opción no válida."; read -p "Presiona Enter." ;;
    esac
done


