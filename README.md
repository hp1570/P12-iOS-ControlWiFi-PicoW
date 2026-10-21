# App iOS · Control WiFi de servomotor con Raspberry Pi Pico W

App desarrollada en **SwiftUI** (patrón MVVM) que se conecta por **HTTP** en la red local a una **Raspberry Pi Pico W** con **MicroPython**, para controlar en tiempo real un **servomotor (0°–180°)** y un **LED indicador**.

Práctica 12 · Internet de las Cosas con Aplicaciones Móviles · Parte 2: WiFi.

**Requisitos:** Xcode 15 o superior · iOS 16 o superior · Raspberry Pi Pico W con firmware MicroPython · red WiFi de 2.4 GHz.

---

## 👥 Autores y aportaciones

| Integrante | Aportación |
|---|---|
| **@hp1570** | App iOS en SwiftUI (`ContentView`, `ControlViewModel`, `PicoAPI`), fragmento de `Info.plist`, programa MicroPython de la Pico W (servidor del servo, conexión WiFi y `config.py`) y README inicial. |
| **Sebastián de Jesús Enguilo Ruiz (Sebitas)** | Correcciones de compilación en Xcode, punto de entrada `@main`, despliegue en iPhone 16 Pro Max, galería de evidencias, bitácora de errores y reporte técnico de la práctica. |

---

## 📁 Estructura del proyecto

| Archivo / Carpeta | Descripción |
|---|---|
| `P12ControlWifiApp.swift` | Punto de entrada (`@main`) de la app en SwiftUI. |
| `ContentView.swift` | Interfaz: campo de IP, botón Conectar, control del LED y slider/botones (0°, 90°, 180°) del servo. |
| `ControlViewModel.swift` | Estado y lógica de la pantalla (`@MainActor`, `ObservableObject`, `@Published`). Guarda la IP en `UserDefaults`. |
| `PicoAPI.swift` | Capa de red: `URLSession` efímera, peticiones `async/await` y decodificación `Codable` del JSON. |
| `Info_plist_fragmento.xml` | Claves de `Info.plist` para permitir HTTP en la red local. |
| `PicoW_MicroPython/config.py` | Red WiFi a la que se conecta la Pico W (SSID `Otoño26`, contraseña y país). |
| `PicoW_MicroPython/wifi_conexion.py` | Función `conectar()`: une la Pico W a la red de `config.py`, parpadea el LED de la placa mientras conecta y devuelve la IP. |
| `PicoW_MicroPython/ej4_servo_wifi.py` | Servidor HTTP de la Pico W: PWM del servo (GP15) y LED (GP16). Se guarda en la placa como `main.py`. |
| `resumen_de_soluci_n_de_errores_xcode.md` | Bitácora de errores de compilación, enlazador y firma resueltos en Xcode. |
| `P12_Enguilo_Sebastian.md` | Reporte técnico completo de la práctica (marco teórico, código, pruebas y conclusiones). |
| `imagenes/` | Capturas de la app en el iPhone y fotos de la planta física. |

---

## 🧭 Cómo funciona

```
 iPhone (app SwiftUI)                     Raspberry Pi Pico W (MicroPython)
 ┌──────────────────┐   GET /servo?grados=90   ┌──────────────────────────┐
 │ ContentView      │ ───────────────────────▶ │ servidor HTTP (puerto 80) │
 │ ControlViewModel │                          │  ├─ PWM 50 Hz → GP15 servo│
 │ PicoAPI          │ ◀─────────────────────── │  └─ GPIO     → GP16 LED   │
 └──────────────────┘  {"led":..,"servo":..}   └──────────────────────────┘
            └──────────── misma red WiFi (2.4 GHz) ────────────┘
```

Cada ruta responde el mismo JSON de estado. La app actualiza la pantalla con lo que **reporta la Pico W**, no con lo que supone que pasó.

---

## 🛠️ Conexión física (hardware)

* **Microcontrolador:** Raspberry Pi Pico W (firmware MicroPython oficial RP2040-W).
* **Servomotor SG90 (o MOT-100):**
  * Señal PWM (naranja/amarillo) → **GP15** (pin físico 20).
  * Positivo (+) (rojo) → **VBUS** (pin físico 40, 5 V del USB).
  * Tierra (–) (café/negro) → **GND** (pin físico 38).
* **LED con resistencia:**
  * Ánodo (+) → **GP16** (pin físico 21) a través de una resistencia de 220 Ω.
  * Cátodo (–) → **GND** (pin físico 23).

**Calibración del servo:** en `ej4_servo_wifi.py`, `PULSO_MIN_US = 500` (0°) y `PULSO_MAX_US = 2500` (180°). Ajústalos si el servo no llega a los extremos o zumba.

---

## 📡 API HTTP de la Pico W

Todas las rutas usan `GET` en el puerto 80 y responden el mismo JSON de estado:

| Endpoint | Parámetros | Respuesta de ejemplo | Acción en hardware |
|---|---|---|---|
| `/` | — | Página HTML de control | Panel web para probar desde el navegador. |
| `/estado` | — | `{"led": false, "servo": 90, "ip": "172.22.46.27"}` | Consulta el estado sin cambiar salidas. |
| `/led/on` | — | `{"led": true, "servo": 90, "ip": "172.22.46.27"}` | Pone GP16 en alto (3.3 V). |
| `/led/off` | — | `{"led": false, "servo": 90, "ip": "172.22.46.27"}` | Pone GP16 en bajo (0 V). |
| `/servo` | `grados=0..180` | `{"led": false, "servo": 180, "ip": "172.22.46.27"}` | Ajusta el ciclo de trabajo del PWM de 50 Hz en GP15. |

Si `grados` no es un número, responde `400`; una ruta desconocida responde `404`.

---

## 🚀 Configuración, compilación y ejecución

### 1. Cargar MicroPython en la Raspberry Pi Pico W
1. Instala el firmware de MicroPython para Pico W y conecta la placa por USB (en Windows aparece como puerto serie, p. ej. `COM9`).
2. Con **Thonny** (*Guardar como › Raspberry Pi Pico*) o con `mpremote`, copia a la raíz de la placa:
   * `config.py`, con la red WiFi `Otoño26`.
   * `wifi_conexion.py`.
   * `ej4_servo_wifi.py` guardado como **`main.py`**, para que arranque solo al encender.
3. Al conectarse, la Pico W imprime su IP en la consola (ejemplo: `172.22.46.27`) e inicia el servidor en el puerto 80. **Esa es la IP que se escribe en la app.**

> **Notas de red:** la Pico W solo funciona con redes de **2.4 GHz** y WPA2 personal (no redes con usuario y contraseña, como las institucionales); si usas el hotspot del celular, activa "Maximizar compatibilidad". Si no encuentra la red, prueba con un nombre de red sin acentos ni "ñ" y cámbialo también en `config.py`.

### 2. Configurar el proyecto en Xcode (macOS)
1. Crea un proyecto **iOS App** con interfaz **SwiftUI** y lenguaje **Swift**.
2. Agrega los archivos fuente (reemplaza los que genera Xcode):
   * `P12ControlWifiApp.swift` (punto de entrada `@main`).
   * `ContentView.swift`.
   * `ControlViewModel.swift`.
   * `PicoAPI.swift`.
3. En **Target › Info › Custom iOS Target Properties** agrega las claves de `Info_plist_fragmento.xml`:
   * `App Transport Security Settings` › `Allows Local Networking` = `YES`.
     Si aun así iOS bloquea HTTP, usa `Allow Arbitrary Loads` = `YES` (menos estricto, aceptable en red local).
   * `Privacy - Local Network Usage Description`: *"La app se conecta a la Raspberry Pi Pico W en tu red WiFi para controlar el LED y el servomotor."*

### 3. Desplegar en un iPhone físico (probado en iPhone 16 Pro Max)
1. Activa el **Modo Desarrollador** en el iPhone: *Ajustes › Privacidad y seguridad › Modo de desarrollo* (pide reiniciar).
2. Conecta el iPhone a la Mac por USB y acepta **Confiar en esta computadora**.
3. En Xcode, en *Signing & Capabilities*, elige tu equipo de firma (*Personal Team*).
4. Si macOS pregunta por `codesign`, escribe la contraseña de la Mac y elige **Siempre permitir**.
5. Selecciona el iPhone como destino y ejecuta con `Cmd + R`.
6. En el iPhone, confía en el perfil de desarrollador: *Ajustes › General › VPN y gestión de dispositivos*.

### 4. Usar la app
1. Conecta el iPhone a la **misma red WiFi** que la Pico W.
2. Escribe la IP de la Pico W y toca **Conectar**. El indicador pasa a verde. La IP se guarda para la próxima vez.
3. **LED:** botones *Encender* / *Apagar*.
4. **Servo:** mueve el slider (el comando se envía **al soltarlo**, para no saturar a la Pico W) o usa los botones 0° / 90° / 180°.
5. La sección *Última respuesta de la Pico W* muestra la petición enviada y lo que respondió la placa.

---

## 📸 Resultados y evidencias

Pruebas en tiempo real con un iPhone 16 Pro Max y la planta física.

### 1. App instalada en el iPhone 16 Pro Max
La app `P12ControlWifi` instalada en el dispositivo físico.
![01 App Instalada](imagenes/01_app_instalada_iphone.png)

### 2. Conexión establecida y LED apagado
Al escribir la IP de la Pico W (`172.22.46.27`) y tocar **Conectar**, el indicador pasa a verde y se confirma que el LED está apagado.
![02 LED Apagado](imagenes/02_led_apagado.png)

### 3. Encendido del LED por WiFi
Al tocar **Encender** se envía `GET /led/on`; la app muestra "ENCENDIDO" y se enciende el LED en GP16.
![03 LED Prendido](imagenes/03_led_prendido.png)

### 4. Servo en posición intermedia (90°)
Servo a 90° con el slider o el botón de acceso rápido.
![04 Servo 90 Grados](imagenes/04_servo_90_grados.png)

### 5. Servo en el extremo mínimo (0°)
`GET /servo?grados=0` lleva el brazo del SG90 al límite inferior.
![05 Servo 0 Grados](imagenes/05_servo_0_grados.png)

### 6. Servo en el extremo máximo (180°)
`GET /servo?grados=180` lleva el servo al límite superior y la respuesta se confirma en la app.
![06 Servo 180 Grados](imagenes/06_servo_180_grados.png)

### 7. Manejo de errores de red
Ante una desconexión o retardo, la app informa la causa probable (*Tiempo agotado*).
![07 Manejo Error Red Timeout](imagenes/07_manejo_error_red_timeout.png)

### 8. Montaje completo de la planta física
Raspberry Pi Pico W, protoboard, cableado del servomotor y resistencias.
![08 Planta Fisica Circuito](imagenes/08_planta_fisica_circuito_pico_w.png)

---

## 🔧 Modificaciones de Sebitas

Cambios hechos al probar la app en Xcode y en el iPhone físico:

1. **Nuevo `P12ControlWifiApp.swift`.** Se agregó el punto de entrada `@main` que abre `ContentView`. Sin él, Xcode fallaba con `Undefined symbol: _main`.
2. **Imports en `ControlViewModel.swift`.** Se agregaron `import SwiftUI` e `import Combine`, necesarios para que `ObservableObject` y `@Published` se reconozcan.
3. **Valor inicial de `ip`.** `@Published var ip` ahora tiene valor por defecto (la IP guardada en `UserDefaults` o `""`), lo que resolvió el error de conformidad con `ObservableObject`.
4. **Documentación y evidencias.** Se agregaron la carpeta `imagenes/` con 8 evidencias, la bitácora `resumen_de_soluci_n_de_errores_xcode.md`, el reporte `P12_Enguilo_Sebastian.md` y el tutorial de despliegue en iPhone.

---

## 🛡️ Solución de problemas

**Mensajes de la app:**

| Mensaje | Causa probable |
|---|---|
| *Tiempo agotado. ¿La Mac o el iPhone están en la MISMA red WiFi que la Pico W?* | El iPhone y la Pico W están en redes distintas o la Pico W está apagada. |
| *La IP … no responde. ¿Está corriendo main.py en la Pico W?* | La IP es incorrecta o el servidor no está corriendo. |
| *Este dispositivo no tiene red WiFi activa.* | El iPhone no tiene WiFi. |
| *iOS bloqueó HTTP: falta 'Allows Local Networking' en Info.plist.* | Faltan las claves de `Info_plist_fragmento.xml`. |

**Errores de Xcode** (enlazador `_main`, `@Published`, firma en Llavero y confianza en el iPhone): consulta la bitácora completa en
👉 **[resumen_de_soluci_n_de_errores_xcode.md](resumen_de_soluci_n_de_errores_xcode.md)**.

---

## 📄 Reporte de la práctica

El reporte técnico completo (marco teórico, código, pruebas de escritorio y conclusiones) está en
👉 **[P12_Enguilo_Sebastian.md](P12_Enguilo_Sebastian.md)**.
