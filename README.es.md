# Insaniquarium Deluxe — Port Nativo para Miyoo Mini / Flip

[Read in English](README.md)

[![Licencia: AGPL v3](https://img.shields.io/badge/Licencia-AGPL_v3-blue.svg)](https://www.gnu.org/licenses/agpl-3.0)
[![Plataforma](https://img.shields.io/badge/Plataforma-Miyoo%20Mini%20%2F%20Flip%20(OnionOS)-red.svg)]()

Port nativo en arquitectura ARMv7 (`armhf`) de **Insaniquarium Deluxe** ejecutándose en **Miyoo Mini Flip** (y probablemente compatible con **Miyoo Mini / Miyoo Mini Plus**) bajo OnionOS.

Este port está construido sobre el trabajo de descompilación de [WinFish](https://github.com/vindirect/winfish), el framework de motor [PopLib](https://github.com/teampopwork/poplib), y el port de PortMaster desarrollado por [SaMeiers](https://github.com/SaMeiers/insaniquarium-port).

---

## Compatibilidad

- **Miyoo Mini Flip**: Completamente probado y verificado en hardware físico (rendimiento fluido y estable, audio sincronizado, temperatura normal y consumo moderado de batería).
- **Miyoo Mini / Miyoo Mini Plus**: Compilado con la toolchain estándar de Miyoo Mini (`glibc 2.28`, ARMv7 Cortex-A7). Aunque no ha sido probado directamente por falta del dispositivo físico, comparte la misma arquitectura SoC/OS y debería funcionar sin problemas. ¡Comentarios y pull requests son bienvenidos!

---

## Aviso Legal Importante: Assets del Juego No Incluidos

**Este repositorio NO contiene assets propietarios del juego.** Es necesario suministrar los archivos de datos desde una copia legítima de **Insaniquarium Deluxe** (versión de Steam, CD-ROM original de PopCap, etc.).

### Archivos Requeridos del Juego

Desde la instalación del juego en PC, copia las siguientes carpetas:

```text
data/
fishsongs/
images/
music/
properties/
sounds/
```

> [!WARNING]
> **Sensibilidad a Mayúsculas y Minúsculas en Linux:**
> A diferencia de Windows, el sistema de archivos de Linux distingue entre mayúsculas y minúsculas (*case-sensitive*). Si el juego reporta que falta una imagen o recurso que sabes que está presente, revisa el nombre del archivo y asegúrate de que coincida exactamente con las mayúsculas/minúsculas solicitadas por el juego.

---

## Instalación en Miyoo Mini / Flip

1. Asegúrate de tener instalado **OnionOS** en el dispositivo.
2. Coloca el archivo `Insaniquarium.port` en la tarjeta SD dentro de:
   ```text
   /mnt/SDCARD/Roms/PORTS/
   ```
3. Coloca el contenido del directorio del port (el binario ejecutable `Insaniquarium`, `script.sh`, `alsoft.conf`, la carpeta `lib/`, etc.) en:
   ```text
   /mnt/SDCARD/Roms/PORTS/Games/Insaniquarium/
   ```
4. Copia las carpetas de recursos originales mencionadas anteriormente (`data/`, `images/`, `music/`, `properties/`, `sounds/`, `fishsongs/`) directamente en:
   ```text
   /mnt/SDCARD/Roms/PORTS/Games/Insaniquarium/
   ```
5. En OnionOS, actualiza la lista de ROMs (*Refresh Roms*), ve a la sección de **Ports** e inicia **Insaniquarium**.

---

## Controles

Dado que Insaniquarium fue concebido originalmente como un juego de PC controlado al 100% con mouse, los botones de la consola operan como un puntero virtual intuitivo:

| Botón | Acción en el Juego |
|---|---|
| **D-Pad / Stick Analógico** | Mover el puntero virtual |
| **A** | Clic Izquierdo (alimentar peces, recoger monedas, disparar a aliens, confirmar) |
| **B** | Clic Derecho (activar habilidad especial de mascota, cancelar / soltar) |
| **X** | Acción secundaria / Cancelar |
| **Y** | Auto-Recolectar todas las monedas (recoge todas las monedas flotantes si está activo en Opciones) |
| **L1 / R1** | Movimiento de Precisión Lento (ralentiza el puntero para mayor exactitud) |
| **Start** | Enter / Pausa / Menú del juego |
| **Select** | Escape / Volver |
| **Botón Menú (Miyoo)** | Game Switcher de OnionOS / Menú del sistema |

> [!TIP]
> **Auto-Recolección de Monedas:** En el menú de *Options* del juego podés activar *Auto Collect*. Con esta opción activa, al presionar **Y** se recogen automáticamente todas las monedas que haya en el acuario sin necesidad de pasar el puntero sobre cada una.

---

## La Historia: Desarrollo, Transparencia sobre IA y Desafíos Técnicos

### Transparencia Absoluta sobre el Uso de IA

Deseo ser totalmente transparente con la comunidad: **no soy programador profesional de sistemas embebidos ni de C++ de bajo nivel.** Previo a este proyecto, tareas como la compilación cruzada de motores heredados, la modificación de toolchains y la depuración del subsistema de audio en Linux excedían mis conocimientos técnicos.

Este port fue posible mediante pair-programming activo con modelos modernos de razonamiento por inteligencia artificial (**DeepSeek V4 Flash** y **Gemini 3.8 Flash**).

En una comunidad que con justa razón desconfía del llamado "AI slop" o código especulativo generado sin criterio, este proyecto se rige por principios opuestos:
- **Cero Tolerancia a Alucinaciones**: Cada cambio fue probado, medido y depurado en hardware físico real (Miyoo Mini Flip) mediante telemetría y logs en vivo.
- **Ingeniería de Causa Raíz**: En lugar de ensayos a ciegas, los modelos se utilizaron para analizar trazas de ejecución, comportamiento del ciclo de frames e interfaces del kernel para localizar el origen exacto de los cuellos de botella.
- **Totalmente Reproducible y Auditable**: Todo el entorno de compilación, Dockerfiles, scripts y parches se publican de forma abierta para que la comunidad pueda inspeccionar, verificar y mejorar el código.

### Problemas Clave Resueltos en Hardware Real

La adaptación a la arquitectura dual-core Cortex-A7 (SigmaStar SSD202D) de la Miyoo presentó desafíos específicos que requirieron diagnóstico y solución técnica:

1. **Latencia y Ralentización en el Audio (Muestreo OSS):**
   - *Problema*: Los efectos de sonido y la música sonaban ralentizados ("en cámara lenta") y con más de un segundo de desfase.
   - *Solución*: La Miyoo utiliza un controlador `/dev/dsp` administrado por el `audioserver` de OnionOS. Se configuró OpenAL Soft (`alsoft.conf`) con el driver OSS forzado a la frecuencia nativa de **48000 Hz** y se mantuvo activo el `audioserver` precargando `libpadsp.so`.

2. **Congelamientos al Iniciar Nivel o Aparecer Aliens:**
   - *Problema*: Al arrancar un nivel o al generarse un alienígena, el juego sufría una congelación de 2 a 3 segundos mientras la música tartamudeaba.
   - *Solución*: La interfaz de streaming de música con OpenMPT (`openmptmusicinterface.cpp`) se saturaba por un tamaño excesivo de buffers. Se optimizó el encolado a bloques de 4x4096 muestras y se cambió la interpolación a lineal ligera, eliminando la inanición de hilos (*thread starvation*).

3. **Caída de FPS en Niveles Avanzados y el Cuello de Botella de "Rotozoom" en SDL3:**
   - *Problema*: Al aumentar la cantidad de peces en el acuario a partir del nivel 3, los fotogramas por segundo caían drásticamente cada vez que un pez nadaba hacia la izquierda.
   - *Solución*: El perfilado reveló que el renderizador por software de SDL3 (`SDL_render_sw.c`) maneja los blits invertidos horizontalmente (`SDL_FLIP_HORIZONTAL`) invocando una rutina compleja de rotación y escalado (`SW_RenderCopyEx`), la cual ejecuta operaciones trigonométricas y **dos asignaciones dinámicas en memoria heap por cada fotograma de pez**. Con decenas de peces en pantalla, la fragmentación y sobrecarga de CPU colapsaban el rendimiento. Se implementó una caché diferida de texturas espejadas (`GetMirroredTexture`), convirtiendo el dibujado inverso en blits directos 1:1 (`SDL_RenderTexture`) con cero asignaciones en tiempo de ejecución.

4. **Regulación de Fotogramas y Consumo de Batería:**
   - *Problema*: El ciclo principal del juego o bien dormía durante intervalos rígidos de 10 ms (generando tirones) o se ejecutaba sin límite (drenando un 10% de batería cada 10 minutos con incremento notable de temperatura).
   - *Solución*: Se ajustó la sincronización de fotogramas para ceder tiempo solo cuando el margen sobre los 16.6 ms es suficiente, se eliminó el costoso blending alfa a pantalla completa en la presentación y se fijó el reloj de CPU en 1200 MHz nominales en lugar del overclock a 1500 MHz.

---

## Compilación desde el Código Fuente

Se incluye un entorno de compilación cruzada reproducible mediante Docker.

### Requisitos Previos

- Docker o Docker Desktop
- Archivo comprimido de la toolchain de Miyoo Mini (`miyoomini-toolchain.tar.xz`)

### Pasos de Compilación

1. Clonar este repositorio incluyendo submódulos:
   ```bash
   git clone --recurse-submodules https://github.com/RAlexander777/Insaniquarium_Miyoo_Mini_Flip.git
   cd Insaniquarium_Miyoo_Mini_Flip
   ```

2. Construir la imagen del compilador en Docker:
   ```bash
   docker build -t miyoo-insaniquarium-builder -f docker/Dockerfile.miyoo .
   ```

3. Ejecutar la compilación dentro del contenedor:
   ```bash
   docker run --rm -v $(pwd):/host -w /host miyoo-insaniquarium-builder ./build-armhf.sh
   ```
   *(O alternativamente: `docker compose run --rm builder`)*

El binario compilado `Insaniquarium` se generará listo para empaquetar y transferir al dispositivo.

---

## Créditos y Agradecimientos

- **PopCap Games / Electronic Arts**: Por crear *Insaniquarium Deluxe*, un clásico entrañable.
- **[WinFish](https://github.com/vindirect/winfish) por vindirect**: Por el extraordinario trabajo de descompilación que permite contar con la lógica moderna del juego.
- **[PopLib](https://github.com/teampopwork/poplib) por Team Popwork**: Por el motor moderno multiplataforma que reemplaza SexyAppFramework.
- **[SaMeiers](https://github.com/SaMeiers/insaniquarium-port)**: Por el port inicial de PortMaster y los scripts de corrección que sirvieron de base directa para esta versión.
- **[bmdhacks](https://github.com/bmdhacks/SDL)**: Por la capa de compatibilidad (shim) SDL3-sobre-SDL2.
- **Comunidad de OnionOS y Miyoo**: Por el desarrollo continuo del ecosistema, toolchains y utilidades de audio.

---

## Licencia

Este port se distribuye bajo la licencia **GNU Affero General Public License v3.0 (AGPL-3.0)**, heredada de `PopLib` e `insaniquarium-port`. Consulta el archivo [LICENSE](LICENSE) para el texto completo.

Los componentes individuales y submódulos conservan sus respectivas licencias originales (SDL, libopenmpt, OpenAL Soft, zlib, miniaudio). Todos los assets originales, gráficos, sonidos y marcas registradas son propiedad exclusiva de PopCap Games / Electronic Arts.
