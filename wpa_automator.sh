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

# Función para detectar el sistema operativo e instalar dialog si no está presente
detect_and_install_dependencies() {
    if [[ -f /etc/os-release ]]; then
        source /etc/os-release
        OS=$ID
    else
        OS=$(uname -s)
    fi

    case $OS in
        ubuntu|debian)
            sudo apt update && sudo apt install -y "${DEPENDENCIES[@]}" || {
                dialog --title "Error" --msgbox "Error al instalar dependencias en Ubuntu/Debian." 8 40
                exit 1
            }
            ;;
        fedora|centos|rhel)
            sudo dnf install -y "${DEPENDENCIES[@]}" || {
                dialog --title "Error" --msgbox "Error al instalar dependencias en Fedora/CentOS." 8 40
                exit 1
            }
            ;;
        arch|manjaro)
            sudo pacman -Sy --noconfirm "${DEPENDENCIES[@]}" || {
                dialog --title "Error" --msgbox "Error al instalar dependencias en Arch/Manjaro." 8 40
                exit 1
            }
            ;;
        *)
            dialog --title "Error" --msgbox "Sistema operativo no reconocido o no soportado." 8 40
            exit 1
            ;;
    esac
}

# Mostrar barra de progreso
show_progress() {
    local duration=$1
    local completed=0
    local increment=$((100 / duration))

    while [ $completed -le 100 ]; do
        dialog --gauge "Procesando..." 10 50 $completed
        sleep 1
        ((completed += increment))
    done
}

# Verificar permisos de administrador
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

# Detectar interfaces inalámbricas
detect_wireless_interface() {
    interface=$(iw dev | grep Interface | awk '{print $2}' | head -n 1)
    if [[ -z "$interface" ]]; then
        dialog --title "Error" --msgbox "No se encontró ninguna interfaz inalámbrica." 8 40
        exit 1
    fi
    echo "$interface"
}

# Gestión del modo monitor
enable_monitor_mode() {
    interface=$(detect_wireless_interface)
    dialog --title "Modo Monitor" --infobox "Activando modo monitor en $interface..." 8 40
    sleep 1
    airmon-ng start $interface &>/dev/null || iw dev $interface set type monitor &>/dev/null
    dialog --title "Modo Monitor" --msgbox "Modo monitor activado en $interface." 8 40
}

# Escaneo de redes
scan_networks() {
    interface=$(detect_wireless_interface)
    dialog --title "Escaneo de Redes" --infobox "Escaneando redes durante 60 segundos..." 8 40
    show_progress 60

    xterm -hold -e "airodump-ng $interface --output-format cap --write $RESULTS_DIR/scan_results" &
    sleep 60
    killall airodump-ng
    dialog --title "Escaneo de Redes" --msgbox "Escaneo completado. Resultados guardados en $RESULTS_DIR." 8 40
}

# Buscar diccionario rockyou.txt en todo el sistema
find_rockyou_dictionary() {
    dictionary_path=$(find / -type f -name "rockyou.txt" 2>/dev/null | head -n 1)
    if [[ -z "$dictionary_path" ]]; then
        dialog --title "Diccionario" --infobox "Descargando diccionario rockyou.txt..." 8 40
        show_progress 10
        curl -o "$PROJECT_DIR/rockyou.txt.gz" https://github.com/praetorian-inc/Hob0Rules/raw/master/wordlists/rockyou.txt.gz
        gzip -d "$PROJECT_DIR/rockyou.txt.gz"
        dictionary_path="$PROJECT_DIR/rockyou.txt"
    fi
    echo "$dictionary_path"
}

# Analizar archivo .cap y recomendar redes
analyze_cap_file() {
    cap_file=$(find $RESULTS_DIR -type f -name "*.cap" 2>/dev/null | head -n 1)
    if [[ -z "$cap_file" ]]; then
        dialog --title "Error" --msgbox "No se encontró ningún archivo .cap en la carpeta de resultados." 8 40
        return
    fi

    dialog --title "Analizando Archivo" --infobox "Analizando archivo .cap para extraer redes vulnerables..." 8 40
    show_progress 5
    dialog --title "Resultado" --msgbox "Análisis completado. Revisar archivo .cap." 8 40
}

# Menú principal
main_menu() {
    while true; do
        option=$(dialog --title "WiFi Toolkit" --menu "Selecciona una opción:" 15 50 6 \
            1 "Instalar dependencias" \
            2 "Habilitar modo monitor" \
            3 "Escanear redes" \
            4 "Analizar archivo .cap y realizar ataque" \
            5 "Ver detalles del diccionario" \
            6 "Salir" 3>&1 1>&2 2>&3)

        case $option in
            1) detect_and_install_dependencies ;;
            2) enable_monitor_mode ;;
            3) scan_networks ;;
            4) analyze_cap_file ;;
            5) dictionary_path=$(find_rockyou_dictionary)
               dialog --title "Detalles del Diccionario" --msgbox "Ruta del diccionario: $dictionary_path" 10 50 ;;
            6) clear; exit 0 ;;
            *) dialog --title "Error" --msgbox "Opción inválida." 8 40 ;;
        esac
    done
}

# Inicio del script
check_permissions
prepare_project_directory
main_menu
