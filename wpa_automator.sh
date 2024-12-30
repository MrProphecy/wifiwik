# Verificar y ajustar permisos del directorio de resultados
prepare_directories() {
    if [[ ! -d "$RESULTS_DIR" ]]; then
        mkdir -p "$RESULTS_DIR"
    fi
    chmod -R 777 "$RESULTS_DIR"
}

# Comprobar y configurar la interfaz en modo monitor
configure_monitor_mode() {
    local interface=$(iw dev | grep Interface | awk '{print $2}' | head -n 1)
    if [[ -z "$interface" ]]; then
        dialog --title "Error" --msgbox "No se encontró ninguna interfaz inalámbrica. Conecta una tarjeta WiFi compatible." 8 40
        exit 1
    fi

    airmon-ng start "$interface" &>/dev/null
    interface_monitor=$(iw dev | grep Interface | awk '{print $2}' | grep "mon" | head -n 1)

    if [[ -z "$interface_monitor" ]]; then
        dialog --title "Error" --msgbox "No se pudo configurar la interfaz en modo monitor." 8 40
        exit 1
    fi

    echo "$interface_monitor"
}

# Escaneo en vivo con validación
live_scan_networks() {
    local interface=$(configure_monitor_mode)
    dialog --title "Escaneo en Vivo" --infobox "Iniciando escaneo en vivo en la interfaz $interface..." 8 40
    sleep 2

    xterm -geometry 80x24+0+0 -hold -e "airodump-ng $interface --output-format cap --write $RESULTS_DIR/live_scan" &
    sleep 10
    killall airodump-ng

    # Validar si el archivo .cap se generó correctamente
    if [[ ! -f "$RESULTS_DIR/live_scan-01.cap" ]]; then
        dialog --title "Error" --msgbox "El archivo live_scan-01.cap no se generó. Verifica los permisos y el estado de la interfaz." 8 40
        exit 1
    fi
}
