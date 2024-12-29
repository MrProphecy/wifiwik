1. Instalar Dependencias
Antes de ejecutar el script, asegúrate de que tienes las herramientas necesarias instaladas:

Aircrack-ng
Net-tools
iwconfig
Ejecuta el siguiente comando para instalar estas herramientas si aún no las tienes:

bash
Copiar código
sudo apt update && sudo apt install aircrack-ng net-tools wireless-tools -y
2. Descargar el Script
Clona el repositorio de GitHub que contiene el script o descárgalo manualmente.

Con Git:

bash
Copiar código
git clone https://github.com/MrProphecy/wifiwik.git
cd wifiwik
Manual:

Ve al enlace del script.
Copia el contenido del archivo.
Crea un archivo en Kali con el siguiente comando:
bash
Copiar código
nano wpa_automator.sh
Pega el contenido copiado y guarda el archivo (CTRL + O, Enter, luego CTRL + X para salir).
3. Dar Permisos de Ejecución
Otorga permisos de ejecución al script:

bash
Copiar código
chmod +x wpa_automator.sh
4. Modo Root
El script probablemente requiere permisos elevados para trabajar con redes Wi-Fi y tarjetas inalámbricas. Cambia al modo root:

bash
Copiar código
sudo su
5. Identificar tu Interfaz Wi-Fi
Antes de ejecutar el script, identifica la interfaz inalámbrica (como wlan0 o wlan1):

bash
Copiar código
iwconfig
Esto mostrará las interfaces disponibles.

6. Ejecutar el Script
Ejecuta el script con la interfaz Wi-Fi que quieras usar:

bash
Copiar código
./wpa_automator.sh
Si necesita opciones adicionales (como argumentos específicos), consulta su contenido para entender los parámetros que acepta. Por ejemplo:

bash
Copiar código
./wpa_automator.sh wlan0
7. Seguir las Instrucciones
El script puede pedirte que selecciones un objetivo, el tipo de ataque, o que proporciones más detalles. Sigue las instrucciones en pantalla.

8. Verificar el Resultado
Al finalizar, el script mostrará los resultados del proceso (como handshakes capturados o claves probadas).

Notas Importantes:
Uso Ético: Utiliza este script solo en redes de las que tienes autorización explícita. Usar herramientas como esta sin permiso es ilegal.
Monitor Mode: Si el script no activa el modo monitor automáticamente, hazlo manualmente antes de ejecutarlo:
bash
Copiar código
airmon-ng start wlan0# wifiwik
Testing Wifi Network 
