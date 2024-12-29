#!/bin/bash

# Verifica si el usuario tiene permisos de root
if [ "$EUID" -ne 0 ]; then
  echo "Por favor, ejecuta el script como root."
  exit
fi

echo "=== Generador de Diccionarios para Redes Wi-Fi ==="
echo "=== Realizado por Viking ==="

# Menú principal
while true; do
  echo ""
  echo "Selecciona una opción:"
  echo "1. Generar diccionario con Crunch"
  echo "2. Crear diccionario personalizado con CUPP"
  echo "3. Usar Rockyou.txt como diccionario"
  echo "4. Salir"
  echo ""
  read -p "Opción: " opcion

  case $opcion in
    1)
      # Crunch
      echo ""
      echo "== Generador con Crunch =="
      read -p "Introduce la longitud mínima: " min_length
      read -p "Introduce la longitud máxima: " max_length
      read -p "Introduce los caracteres (ejemplo: abc123): " caracteres
      read -p "Nombre del archivo de salida (ejemplo: diccionario.txt): " output_file

      echo "Generando diccionario con Crunch..."
      crunch "$min_length" "$max_length" "$caracteres" -o "$output_file"
      echo "Diccionario generado y guardado en: $output_file"
      ;;

    2)
      # CUPP
      echo ""
      echo "== Generador con CUPP =="
      echo "Ejecutando CUPP en modo interactivo..."
      cupp -i
      ;;

    3)
      # Rockyou.txt
      echo ""
      echo "== Diccionario Rockyou.txt =="
      if [ ! -f "/usr/share/wordlists/rockyou.txt.gz" ]; then
        echo "El archivo Rockyou.txt no está disponible. Instalándolo ahora..."
        apt install -y wordlists
      fi

      if [ ! -f "/usr/share/wordlists/rockyou.txt" ]; then
        echo "Descomprimiendo Rockyou.txt..."
        gunzip /usr/share/wordlists/rockyou.txt.gz
      fi

      read -p "Nombre del archivo de salida (dejar en blanco para usar por defecto): " output_file
      if [ -z "$output_file" ]; then
        output_file="rockyou_copy.txt"
      fi

      cp /usr/share/wordlists/rockyou.txt "$output_file"
      echo "Diccionario copiado a: $output_file"
      ;;

    4)
      echo "Saliendo del generador de diccionarios."
      exit 0
      ;;

    *)
      echo "Opción inválida. Intenta nuevamente."
      ;;
  esac
done
