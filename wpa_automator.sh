#!/bin/bash

# Colores para la salida
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # Sin color

# Dependencias necesarias
DEPENDENCIES=("aircrack-ng" "xterm" "iw")

# Directorio para resultados y diccionarios
RESULTS_DIR="./resultados_wifi"
DICT_DIR="./diccionarios"

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

# Crear directorios necesarios
prepare_directories() {
    clear_screen
    mkdir -p "$RESULTS_DIR"
    mkdir -p "$DICT_DIR"
    echo -e "${GREEN}[+] Directorios preparados: $RESULTS_DIR, $DICT_DIR${NC}"
    sleep 2
}

# Gestionar el modo monitor
manage_monitor_mode() {
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

    monitor_enabled=()
    for iface in $interfaces; do
        mode=$(iw dev $iface info | grep -i type | awk '{print $2}')
        if [[ "$mode" == "monitor" ]]; then
            monitor_enabled+=($iface)
        fi
    done

    if [[ ${#monitor_enabled[@]} -gt 0 ]]; then
        echo -e "${YELLOW}[!] Se detectaron interfaces en modo monitor:${NC}"
        for iface in "${monitor_enabled[@]}"; do
            echo -e "  - ${iface}"
        done
        echo -e "${YELLOW}[?] ¿Deseas deshabilitar el modo monitor? (y/n)${NC}"
        read -p "Respuesta: " response
        if [[ "$response" == "y" ]]; then
            for iface in "${monitor_enabled[@]}"; do
                echo -e "${BLUE}[+] Deshabilitando modo monitor en ${iface}...${NC}"
                airmon-ng stop $iface || iw dev $iface set type managed
                echo -e "${GREEN}[+] ${iface} ahora está en modo gestionado.${NC}"
            done
        fi
    fi

    echo -e "${BLUE}[+] ¿Habilitar modo monitor en alguna tarjeta? (y/n)${NC}"
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
    xterm -hold -e "airodump-ng wlan0 --output-format csv --write ${RESULTS_DIR}/scan_results" &
    sleep 60
    killall airodump-ng
    echo -e "${GREEN}[+] Escaneo completado. Resultados guardados.${NC}"
    sleep 2
}

# Realizar ataque con diccionario
dictionary_attack() {
    clear_screen
    echo -e "${BLUE}[+] Preparando ataque con diccionario.${NC}"
    echo -e "${YELLOW}[?] Ingresa la ruta al archivo .cap generado:${NC}"
    read -p "Archivo .cap: " cap_file
    if [[ ! -f "$cap_file" ]]; then
        echo -e "${RED}[-] Archivo no encontrado.${NC}"
        return
    fi
    echo -e "${YELLOW}[?] Ingresa la ruta al archivo de diccionario:${NC}"
    read -p "Diccionario: " dictionary
    if [[ ! -f "$dictionary" ]]; then
        echo -e "${RED}[-] Diccionario no encontrado.${NC}"
        return
    fi
    echo -e "${BLUE}[+] Ejecutando ataque...${NC}"
    xterm -hold -e "aircrack-ng -w $dictionary -b <BSSID> $cap_file"
}

# Menú principal
main_menu() {
    while true; do
        clear_screen
        echo -e "${BLUE}[=]==================== Menú Principal ====================[=]${NC}"
        echo -e "${GREEN}1.${NC} Verificar e instalar dependencias"
        echo -e "${GREEN}2.${NC} Gestionar modo monitor"
        echo -e "${GREEN}3.${NC} Escanear redes"
        echo -e "${GREEN}4.${NC} Realizar ataque con diccionario"
        echo -e "${GREEN}5.${NC} Salir"
        echo -e "${BLUE}[=]=====================================================[=]${NC}"
        read -p "Selecciona una opción: " option

        case $option in
            1) install_dependencies ;;
            2) manage_monitor_mode ;;
            3) scan_networks ;;
            4) dictionary_attack ;;
            5) echo -e "${RED}[-] Saliendo...${NC}"; exit 0 ;;
            *) echo -e "${RED}[-] Opción no válida.${NC}"; sleep 2 ;;
        esac
    done
}

# Inicio del script
check_permissions
prepare_directories
main_menu
