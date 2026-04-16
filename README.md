# TabletScale-Linux 🖊️

**TabletScale-Linux** es un script ligero diseñado para corregir la hipersensibilidad y las deformaciones de aspecto en tabletas gráficas de marcas genéricas (Gadnic, Huion, Ugee, XP-Pen) cuando se usan en Linux (X11).

---

## Contexto Técnico: Por qué xsetwacom no funciona

Las tabletas genéricas (identificadas como `SZ PING-IT INC.` o chipsets `Gotop`) son gestionadas en Linux por el driver básico del kernel `hid-generic`. 
* **Limitación:** Herramientas estándar de la industria como `xsetwacom` o `OpenTabletDriver` requieren drivers específicos (como `wacom` o *report parsers* dedicados). Al usar `hid-generic`, la tableta es invisible para ellos.
* **Solución:** Este script interactúa directamente con el servidor X11 mediante `xinput`, alterando la **Matriz de Transformación de Coordenadas**, evadiendo la necesidad de drivers privativos.

### Fragmentación del Dispositivo
Al conectar la tableta, el sistema operativo no la reconoce como una sola entidad, sino que la fragmenta en múltiples interfaces virtuales. Puedes verificarlo ejecutando `xinput list`.

* **El Lápiz (Pen):** Controla el cursor, la presión y la escala. (Objetivo de este script).
* **Los Botones (Pad):** Se registran como un dispositivo de **Teclado** independiente (ej. `T505 Graphic Tablet Keyboard`).

# MOSTRAR MI OUTPUT PARA ESE COMANDO
---

## El Problema
Por defecto, Linux mapea toda la superficie de tu tableta a toda la superficie de tu monitor. Si tu monitor es mucho más grande que tu tableta, un trazo de **1 cm** físico se convierte en **3 cm** en pantalla. Esto arruina la precisión y la memoria muscular, obligándote a dibujar o escribir de forma microscópica.

## La Solución: Escala 1:1 Física
Este script calcula automáticamente la **Coordinate Transformation Matrix** basándose en las dimensiones reales (en centímetros) de tus dispositivos. Si dibujas un círculo de 5 cm en tu tableta, obtendrás un círculo de 5 cm en tu pantalla, ubicado exactamente donde tú elijas (esquinas o centro).

---

## Instalación y Requisitos

Asegúrate de tener instaladas las dependencias necesarias:
```bash
sudo apt update
sudo apt install xinput bc libnotify-bin
```

Clona el repositorio:
```bash
git clone https://github.com/tu-usuario/TabletScale-Linux.git
cd TabletScale-Linux
chmod +x tablet-transformer.sh
```

---

## 🛠️ Cómo usarlo

1. **Identifica tu dispositivo:**
   Ejecuta `xinput list` y busca el nombre de tu Stylus/Pen. 
   > *Ejemplo: "SZ PING-IT INC. T505 Graphic Tablet Pen (0)"*

2. **Ejecuta el configurador:**
   ```bash
   ./tablet-transformer.sh
   ```

3. **Ingresa los datos:**
   * **Dimensiones de la tableta:** El área activa (puedes medirla con una regla).
   * **Dimensiones del monitor:** El área visible de tu pantalla.
   * **Posición:** Elige si quieres que el área de trabajo quede en el centro o arrinconada para alcanzar las herramientas del software (Krita, GIMP, Xournal++).
   * **Modo Zurdo:** Aplica una rotación de 90° para usar la tableta en posición vertical.

---

## ⚙️ Automatización (Crear un lanzador)

Para no ejecutar el script cada vez, puedes crear un archivo `.desktop` en `~/.local/share/applications/tablet.desktop`.El script debe ser ejecutable (`chmod -x`). Además, en algunos entornos, debes hacer clic derecho sobre el archivo .desktop en el gestor de archivos y seleccionar "Allow Launching" (Permitir lanzamiento). Para escribir la ruta de tu archivo no utilices (~), utiliza la ruta completa:

```ini
[Desktop Entry]
Type=Application
Name=Configurar Tableta 1:1
Exec=/ruta/a/tu/script/tablet-transformer.sh
Icon=preferences-desktop-display
Terminal=true
Categories=Utility;
```

---

## 📈 ¿Cómo funciona la magia?

El script utiliza álgebra lineal para inyectar valores en la matriz de transformación de X11. La fórmula principal es:

$$Scale = \frac{Tablet_{cm}}{Monitor_{cm}}$$

La matriz resultante se aplica mediante:
`xinput set-prop <ID> "Coordinate Transformation Matrix" <matriz>`

---

## 🎛️ Configuración de Botones Laterales (Atajos)

El script `TabletScale-Linux` ajusta la escala del lápiz. Para configurar los botones físicos de la tableta, se requiere un enfoque distinto debido a la fragmentación del hardware.

* **(1) Síntoma observado:** Comandos como `xinput set-button-map` fallan o no tienen efecto sobre los botones físicos.
* **(2) Diagnóstico probable:** Los botones laterales no emiten eventos de ratón (buttons), sino códigos de teclado (keycodes).
* **(3) Comandos/tests a ejecutar:**
  1. Identificar el ID del "Keyboard" de la tableta con `xinput list`.
  2. Ejecutar `xinput test <ID>` (ej. `xinput test 18`).
  3. Presionar un botón físico. La salida mostrará `key press 64` (o el número correspondiente).
* **(4) Solución sugerida:** Instalar y utilizar `input-remapper` para interceptar los keycodes y asignarles atajos.
  ```bash
  sudo apt install input-remapper input-remapper-gtk

---

## Historial de Intentos y Limitaciones Conocidas

Para desarrolladores que busquen ampliar la compatibilidad, documenté los enfoques que **no** funcionan con hardware `Gotop / PING-IT` bajo el driver `hid-generic`:

| Método Intentado | Resultado | Motivo Técnico |
| :--- | :--- | :--- |
| **Digimend-dkms** | Error de compilación | El código fuente carece de soporte para las funciones de temporización de kernels modernos (ej. error en `del_timer_sync`). |
| **OpenTabletDriver** | Dispositivo ignorado | Ausencia de un *report parser* específico para este chipset. `hid-generic` no suelta el dispositivo para permitir la captura a nivel usuario. |
| **Driver 10moons/WinTab** | Inoperable | Linux no permite forzar la desvinculación de `usbhid` sin romper el dispositivo temporalmente. No hay soporte nativo para drivers de Windows adaptados. |
| **Reglas udev (`ENV{ID_IGNORE}="1"`)** | Sin efecto | Manipular `hidraw` directamente requiere escribir un traductor de datos (parser) desde cero. |

---

## Contribuir
Si tienes una tableta que no es detectada automáticamente o quieres mejorar la lógica de los offsets, ¡siéntete libre de abrir un Pull Request!

**Desarrollado por Matías Collado**

---
