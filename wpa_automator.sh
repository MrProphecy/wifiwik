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

# Dependencias necesarias
DEPENDENCIES=("aircrack-ng" "xterm" "iw")

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

# Crear carpeta del proyecto
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
    xterm -hold -e "airodump-ng wlan0 --output-format csv --write $PROJECT_DIR/scan_results" &
    sleep 60
    killall airodump-ng
    echo -e "${GREEN}[+] Escaneo completado. Resultados guardados en $PROJECT_DIR.${NC}"
    sleep 2
}

# Gestión de diccionarios
manage_dictionaries() {
    clear_screen
    echo -e "${BLUE}[+] Verificando diccionarios en $PROJECT_DIR...${NC}"
    dictionaries=$(find "$PROJECT_DIR" -type f -name "*.txt")

    if [[ -z "$dictionaries" ]]; then
        echo -e "${RED}[-] No se encontraron diccionarios en la carpeta del proyecto.${NC}"
        echo -e "${BLUE}[?] ¿Deseas descargar el diccionario 'rockyou.txt'? (y/n)${NC}"
        read -p "Respuesta: " response

        if [[ "$response" == "y" ]]; then
            echo -e "${BLUE}[+] Descargando diccionario...${NC}"
            curl -o "$PROJECT_DIR/rockyou.txt.gz" https://github.com/praetorian-inc/Hob0Rules/raw/master/wordlists/rockyou.txt.gz
            gzip -d "$PROJECT_DIR/rockyou.txt.gz"
            echo -e "${GREEN}[+] Diccionario descargado y descomprimido en $PROJECT_DIR/rockyou.txt${NC}"
        else
            echo -e "${RED}[-] Operación cancelada.${NC}"
        fi
    else
        echo -e "${GREEN}[+] Diccionarios encontrados:${NC}"
        echo "$dictionaries"
    fi
    sleep 2
}

# Realizar ataque con diccionario
dictionary_attack() {
    clear_screen
    echo -e "${BLUE}[+] Preparando ataque con diccionario.${NC}"

    # Solicitar archivo .cap
    while true; do
        echo -e "${YELLOW}[?] Ingresa la ruta al archivo .cap generado:${NC}"
        read -p "Archivo .cap: " cap_file
        if [[ -f "$cap_file" ]]; then
            echo -e "${GREEN}[+] Archivo .cap encontrado: $cap_file${NC}"
            break
        else
            echo -e "${RED}[-] Archivo no encontrado. Inténtalo nuevamente.${NC}"
        fi
    done

    # Solicitar diccionario
    while true; do
        echo -e "${YELLOW}[?] Ingresa la ruta al archivo de diccionario:${NC}"
        read -p "Diccionario: " dictionary
        if [[ -f "$dictionary" ]]; then
            echo -e "${GREEN}[+] Diccionario encontrado: $dictionary${NC}"
            break
        else
            echo -e "${RED}[-] Diccionario no encontrado. Inténtalo nuevamente.${NC}"
        fi
    done

    # Solicitar BSSID
    echo -e "${YELLOW}[?] Ingresa el BSSID de la red objetivo:${NC}"
    read -p "BSSID: " bssid

    # Ejecutar ataque con aircrack-ng
    echo -e "${BLUE}[+] Ejecutando ataque...${NC}"
    xterm -hold -e "aircrack-ng -w $dictionary -b $bssid $cap_file" &
    sleep 2
}

# Menú principal
main_menu() {
    while true; do
        clear_screen
        echo -e "${BLUE}[=]==================== Menú Principal ====================[=]${NC}"
        echo -e "${GREEN}1.${NC} Verificar e instalar dependencias"
        echo -e "${GREEN}2.${NC} Habilitar modo monitor"
        echo -e "${GREEN}3.${NC} Escanear redes"
        echo -e "${GREEN}4.${NC} Gestionar diccionarios"
        echo -e "${GREEN}5.${NC} Realizar ataque con diccionario"
        echo -e "${GREEN}6.${NC} Salir"
        echo -e "${BLUE}[=]=====================================================[=]${NC}"
        read -p "Selecciona una opción: " option

        case $option in
            1) install_dependencies ;;
            2) enable_monitor_mode ;;
            3) scan_networks ;;
            4) manage_dictionaries ;;
            5) dictionary_attack ;;
            6) echo -e "${RED}[-] Saliendo...${NC}"; exit 0 ;;
            *) echo -e "${RED}[-] Opción no válida.${NC}"; sleep 2 ;;
        esac
    done
}

# Inicio del script
check_permissions
prepare_project_directory
main_menu
