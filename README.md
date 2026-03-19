# Script de configuración de red

Script en Bash que permite gestionar interfaces de red.

## Requisitos
- Ejecutar como root
- Se tienen que tener instalados los paquetes: iproute2, net-tools, wireless-tools, wpasupplicant, isc-dhcp-client

## Uso
1. Se deben dar permiso de ejecución: `chmod +x conexion_red.sh`
2. Para ejecutar: `sudo ./conexion_red.sh`
3. Es necesario deshabilitar el NetworkManager `systemctl stop NetworkManager`
`systemctl disable NetworkManager`, esto para evitar interferencias con los manejadores gráficos
4. Posterior a su uso se puede volver a habilitar el NetworkManager.
5. Se muestran menús con las opciones a realizar

## Funcionalidades
- Mostrar interfaces disponibles
- Activar/desactivar interfaces
- Conexión cableada (DHCP/estática) temporal y permanente
- Conexión Wi-Fi con escaneo (cifrado WPA/abierto) temporal y permanente
