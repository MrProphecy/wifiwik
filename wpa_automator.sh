#!/bin/bash

# Colores para salida
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # Sin color

# Dependencias necesarias
DEPENDENCIES=("aircrack-ng" "xterm" "iw")

# Directorio para resultados y diccionarios
RESULTS_DIR="./resultados_wifi"
DICT_DIR="./diccionarios"

# Verificar permisos de administrador
if [[ $EUID -ne 0 ]]; then
  echo -e "${RED}[-] Este script debe ejecutarse como administrador. Usa 'sudo'.${NC}"
  exit 1
fi

# Verificar e instalar dependencias
install_dependencies() {
  echo -e "${GREEN}[+] Verificando dependencias necesarias...${NC}"
  for dep in "${DEPENDENCIES[@]}"; do
    if ! command -v $dep &>/dev/null; then
      echo -e "${RED}[-] Dependencia '$dep' no encontrada. Instalando...${NC}"
      apt-get install -y $dep || { echo -e "${RED}[-] Error al instalar '$dep'.${NC}"; exit 1; }
    else
      echo -e "${GREEN}[+] '$dep' ya está instalado.${NC}"
    fi
  done
}

# Crear directorios necesarios
prepare_directories() {
  mkdir -p "$RESULTS_DIR"
  mkdir -p "$DICT_DIR"
  echo -e "${GREEN}[+] Directorios preparados: $RESULTS_DIR, $DICT_DIR${NC}"
}

# Escaneo de tarjetas y modo monitor
scan_and_enable_monitor() {
  echo -e "${GREEN}[+] Detectando interfaces inalámbricas...${NC}"
  interfaces=$(iw dev | grep Interface | awk '{print $2}')

  if [[ -z "$interfaces" ]]; then
    echo -e "${RED}[-] No se encontraron tarjetas inalámbricas.${NC}"
    exit 1
  fi

  echo -e "${GREEN}[+] Interfaces detectadas:${NC}"
  for iface in $interfaces; do
    echo -e "  - ${iface}"
  done

  monitor_capable=()
  for iface in $interfaces; do
    supports_monitor=$(iw list | grep -A 10 "Interface $iface" | grep "Supported interface modes" -A 10 | grep "monitor")
    if [[ -n "$supports_monitor" ]]; then
      echo -e "  ${GREEN}[+] ${iface} soporta modo monitor.${NC}"
      monitor_capable+=($iface)
    else
      echo -e "  ${RED}[-] ${iface} no soporta modo monitor.${NC}"
    fi
  done

  if [[ ${#monitor_capable[@]} -eq 0 ]]; then
    echo -e "${RED}[-] No se encontraron tarjetas que soporten modo monitor.${NC}"
    exit 1
  fi

  echo -e "${GREEN}[+] Tarjetas con modo monitor:${NC}"
  for iface in "${monitor_capable[@]}"; do
    echo -e "  - ${iface}"
  done

  echo -e "${GREEN}[+] ¿Deseas habilitar el modo monitor en alguna tarjeta? (y/n)${NC}"
  read -p "Respuesta: " response

  if [[ "$response" == "y" ]]; then
    echo -e "${GREEN}[+] Selecciona la tarjeta para habilitar modo monitor:${NC}"
    select iface in "${monitor_capable[@]}"; do
      if [[ -n "$iface" ]]; then
        echo -e "${GREEN}[+] Habilitando modo monitor en ${iface}...${NC}"
        airmon-ng start $iface || iw dev $iface set type monitor
        echo -e "${GREEN}[+] ${iface} está ahora en modo monitor.${NC}"
        break
      else
        echo -e "${RED}[-] Selección inválida.${NC}"
      fi
    done
  else
    echo -e "${RED}[-] Operación cancelada por el usuario.${NC}"
  fi
}

# Escaneo de redes y recomendación
scan_networks() {
  echo -e "${GREEN}[+] Escaneando redes WiFi en una nueva ventana...${NC}"
  xterm -hold -e "airodump-ng wlan0" &  # Cambia wlan0 por tu interfaz activa
  echo -e "${GREEN}[+] Escaneo iniciado. Espera unos segundos...${NC}"
  sleep 10
}

analyze_networks() {
  echo -e "${GREEN}[+] Procesando redes detectadas...${NC}"

  # Simulación de salida de redes (modificar según el comando real)
  networks=(
    "Red_A\t-67\tWPA2"
    "Red_B\t-90\tWEP"
    "Red_C\t-40\tOPEN"
    "Red_D\t-70\tWPA"
  )

  echo -e "${GREEN}[+] Clasificando redes por vulnerabilidad...${NC}"
  recommended=()
  for net in "${networks[@]}"; do
    signal=$(echo $net | awk '{print $2}')
    security=$(echo $net | awk '{print $3}')
    if [[ "$security" == "OPEN" || "$security" == "WEP" ]]; then
      recommended+=("$net")
    elif [[ "$security" == "WPA" && "$signal" -lt -70 ]]; then
      recommended+=("$net")
    fi
  done

  timestamp=$(date '+%Y%m%d_%H%M%S')
  results_file="${RESULTS_DIR}/redes_${timestamp}.txt"
  printf "%-15s %-10s %-10s\n" "SSID" "Señal" "Seguridad" > "$results_file"
  for net in "${networks[@]}"; do
    printf "%-15s %-10s %-10s\n" $(echo $net | tr '\t' ' ') >> "$results_file"
  done

  echo -e "${GREEN}[+] Resultados guardados en: ${results_file}${NC}"

  echo -e "${GREEN}[+] Redes recomendadas:${NC}"
  for rec in "${recommended[@]}"; do
    echo -e "  ${GREEN}[+] $(echo $rec | tr '\t' ' ')${NC}"
  done
}

# Ataque con diccionario
dictionary_attack_menu() {
  echo -e "${GREEN}[+] Menú de Ataque con Diccionario:${NC}"
  # Similar a lo desarrollado anteriormente
}

# Menú principal
main_menu() {
  while true; do
    echo -e "${GREEN}[+] Menú principal:${NC}"
    echo "1. Verificar e instalar dependencias"
    echo "2. Escanear y habilitar modo monitor"
    echo "3. Escanear redes"
    echo "4. Analizar y recomendar redes"
    echo "5. Ataque con diccionario"
    echo "6. Salir"
    read -p "Elige una opción: " option

    case $option in
      1) install_dependencies ;;
      2) scan_and_enable_monitor ;;
      3) scan_networks ;;
      4) analyze_networks ;;
      5) dictionary_attack_menu ;;
      6) echo -e "${RED}[-] Saliendo...${NC}"; exit 0 ;;
      *) echo -e "${RED}[-] Opción no válida.${NC}" ;;
    esac
  done
}

prepare_directories
main_menu
