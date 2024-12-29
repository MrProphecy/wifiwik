Manual de Administrador y Usuario: WiFi Wik Automator




    1. Introducción

    

El WiFi Wik Automator es una herramienta diseñada para automatizar tareas relacionadas con la auditoría de redes inalámbricas WPA/WPA2. Este manual proporciona una guía completa para administradores y usuarios, explicando cómo utilizar el script, qué esperar en cada paso y cómo resolver problemas comunes.



    2. Descripción del Script

    

El WiFi Wik Automator automatiza tareas complejas como la captura de paquetes y el crackeo de handshakes utilizando herramientas de auditoría como aircrack-ng y airodump-ng. Permite analizar redes, probar su seguridad y realizar pruebas éticas dentro de un flujo simplificado y guiado.

Nota importante: El script debe usarse solo en redes propias o con autorización explícita. Su uso indebido puede ser ilegal.



    3. Funcionamiento del Script

      

El script realiza las siguientes funciones:

Verificación de Dependencias: Asegura que las herramientas necesarias están instaladas.

Selección de Interfaz WiFi: Permite al usuario elegir la interfaz WiFi a utilizar.

Modo Monitor: Activa el modo monitor en la interfaz seleccionada.

Escaneo de Redes: Lista redes disponibles cercanas.

Captura de Paquetes: Captura tráfico de una red objetivo para obtener el handshake.

Crackeo de Handshake: Intenta descifrar el handshake capturado (opcional).

Restauración del Modo Managed: Devuelve la interfaz WiFi a su estado normal tras finalizar.



    4. Manual de Uso

    

Requisitos Previos

Kali Linux o una distribución similar con soporte para herramientas de auditoría WiFi.

Permisos de superusuario (root).

Tarjeta de red WiFi compatible con modo monitor.

Conexión a Internet para descargar dependencias.

Instrucciones de Ejecución


Descargar el Script:

curl -o wpa_automator.sh https://raw.githubusercontent.com/MrProphecy/wifiwik/main/wpa_automator.sh


Dar Permisos de Ejecución:

chmod +x wpa_automator.sh


Ejecutar el Script:

sudo ./wpa_automator.sh


Sigue las instrucciones interactivas proporcionadas en pantalla.



    5. Explicación Paso a Paso

    

Verificación de Dependencias

El script comprueba si aircrack-ng, net-tools y wireless-tools están instalados.

Si faltan, las instala automáticamente utilizando apt.

Selección de Interfaz WiFi

Muestra las interfaces disponibles mediante iwconfig.

Solicita al usuario seleccionar la interfaz a utilizar (e.g., wlan0).

Modo Monitor

Cambia la interfaz seleccionada a modo monitor utilizando airmon-ng.

Verifica que el cambio haya sido exitoso antes de proceder.

Escaneo de Redes

Utiliza airodump-ng para listar redes WiFi cercanas.

Proporciona información como BSSID, canal y ESSID de las redes.

El usuario debe anotar los datos de la red objetivo.

Captura de Paquetes

Inicia la captura de tráfico en la red objetivo.

Espera a obtener un handshake válido.

Detiene la captura automáticamente tras un tiempo determinado.

Crackeo de Handshake (Opcional)

Solicita un diccionario de contraseñas (por defecto: /usr/share/wordlists/rockyou.txt).

Intenta descifrar el handshake utilizando aircrack-ng.

Muestra los resultados al usuario.

Restauración del Modo Managed

Devuelve la interfaz al modo normal (managed) para su uso habitual.

Verifica que la restauración haya sido exitosa.



    6. Preguntas Frecuentes (FAQ)

    

  FAQ 1: ¿Qué ocurre si no tengo permisos root?
  

Respuesta: El script requiere permisos root para ejecutarse. Si no eres root, muestra un mensaje de error y se detiene. Utiliza sudo para ejecutarlo:

sudo ./wpa_automator.sh


  FAQ 2: ¿Qué sucede si no tengo las herramientas necesarias instaladas?
  

Respuesta: El script verifica automáticamente la presencia de las herramientas necesarias y las instala si no están disponibles. Asegúrate de tener conexión a Internet.


  FAQ 3: ¿Qué pasa si no se detecta mi interfaz WiFi?
  

Respuesta: Si no se detecta ninguna interfaz:

Verifica que tu tarjeta de red esté conectada correctamente.

Asegúrate de que tu tarjeta sea compatible con modo monitor.

Instala los controladores necesarios para tu tarjeta.


  FAQ 4: ¿Es obligatorio crackear el handshake?
  

Respuesta: No, puedes optar por no realizar el crackeo. El script te permite omitir este paso.


  FAQ 5: ¿Qué debo hacer si no se captura el handshake?
  

Respuesta:

Asegúrate de que hay actividad en la red objetivo.

Prueba acercarte al punto de acceso para mejorar la captura de paquetes.

Repite el proceso de captura si es necesario.






            Intención del Uso y Ética


El script WiFi Vik Automator ha sido creado por Viking como una herramienta educativa y de divulgación en el campo de la ciberseguridad. Su propósito es fomentar el conocimiento sobre la seguridad de redes inalámbricas, permitiendo a los usuarios comprender cómo protegerse frente a ataques y cómo evaluar la fortaleza de sus propias redes.

El autor, Viking, promueve el uso de esta herramienta únicamente en entornos controlados o con el permiso explícito del propietario de la red. El uso indebido de esta herramienta en redes ajenas sin autorización constituye una violación de la ley y de los principios éticos fundamentales.



            Colaboración y Compartición

            

Se invita a la comunidad a contribuir al desarrollo y mejora de esta herramienta a través del repositorio en GitHub. Las contribuciones pueden incluir:

            Reportes de errores.

            Mejora del código.

            Inclusión de nuevas funcionalidades.

Cómo contribuir:

            Clona el repositorio: git clone <URL>

            Realiza los cambios necesarios.

            Envía un pull request detallando las mejoras o correcciones realizadas.

            El objetivo final de esta herramienta es educar, concienciar y reforzar la seguridad digital.
