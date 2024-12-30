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

# Menú principal
main_menu() {
    while true; do
        option=$(dialog --title "WiFi Toolkit" --menu "Selecciona una opción:" 20 60 10 \
            1 "Instalar dependencias" \
            2 "Salir" 3>&1 1>&2 2>&3)

        case $option in
            1) install_dependencies ;;
            2) clear; exit 0 ;;
            *) dialog --title "Error" --msgbox "Opción no válida." 8 50 ;;
        esac
    done
}

# Inicio del script
prepare_project_directory
main_menu
