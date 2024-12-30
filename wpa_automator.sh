# Escanear redes con visualización en vivo
scan_networks_live() {
    interface=$(detect_wireless_interface)
    results_file="$RESULTS_DIR/scan_results-$(date +%Y%m%d%H%M%S).csv"

    # Usar xterm para visualizar en tiempo real
    dialog --title "Escaneo de Redes" --msgbox "El escaneo en vivo comenzará en una ventana separada. Cierra la ventana de escaneo para detenerlo." 8 50
    xterm -hold -e "airodump-ng $interface --output-format csv --write $results_file" &

    # Esperar que el usuario termine el escaneo
    dialog --title "Escaneo en Progreso" --yesno "¿Deseas finalizar el escaneo ahora?" 8 50
    if [[ $? -eq 0 ]]; then
        killall airodump-ng
        if [[ -f "${results_file}-01.csv" ]]; then
            dialog --title "Resultados del Escaneo" --textbox "${results_file}-01.csv" 20 80
        else
            dialog --title "Error" --msgbox "No se generaron resultados del escaneo." 8 50
        fi
    else
        dialog --title "Escaneo Continuando" --msgbox "El escaneo continuará en la ventana separada." 8 50
    fi
}

