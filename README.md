# App iOS · Control WiFi de servomotor con Raspberry Pi Pico W

App en **SwiftUI** que se conecta por WiFi (HTTP en la red local) a una **Raspberry Pi Pico W** para controlar un **servomotor** (0°–180°) y un LED.

## Archivos

| Archivo | Qué hace |
|---|---|
| `ContentView.swift` | Interfaz: campo de IP, botón Conectar, control del LED y slider/botones del servo. |
| `ControlViewModel.swift` | Estado y lógica de la pantalla (patrón MVVM). Guarda la IP en `UserDefaults`. |
| `PicoAPI.swift` | Capa de red: peticiones HTTP con `URLSession` + `async/await` y decodificación del JSON. |
| `Info_plist_fragmento.xml` | Claves de `Info.plist` necesarias para permitir HTTP en red local. |
| `PicoW_MicroPython/config.py` | Red WiFi a la que se conecta la Pico W (SSID, contraseña y país). |
| `PicoW_MicroPython/wifi_conexion.py` | Función `conectar()` que une la Pico W a la red de `config.py` y devuelve su IP. |
| `PicoW_MicroPython/ej4_servo_wifi.py` | Servidor HTTP de la Pico W que mueve el servo (GP15) y el LED (GP16). |

## Raspberry Pi Pico W (MicroPython)

1. Instala el firmware de MicroPython para Pico W y abre **Thonny**.
2. Guarda en la Pico W los tres archivos de `PicoW_MicroPython/`
   (`ej4_servo_wifi.py` guárdalo como **`main.py`** para que arranque solo al conectarla).
3. La Pico W se conecta a la red configurada en `config.py` (red de **2.4 GHz**):
   `SSID = "Otoño26"`.
4. Al conectarse imprime su IP en la consola de Thonny: esa es la IP que se escribe en la app.

Conexión del servo (SG90): señal → GP15 (pin 20), rojo → VBUS (pin 40), café/negro → GND (pin 38).
LED: GP16 (pin 21) → resistencia 220 Ω → LED → GND (pin 23).

## API que espera de la Pico W

Todas las rutas son `GET` y responden el mismo JSON de estado:

```
/estado               -> {"led": false, "servo": 90, "ip": "192.168.x.x"}
/led/on   /led/off
/servo?grados=0..180
```

## Cómo usarla

1. En Xcode crea un proyecto **iOS App** (interfaz SwiftUI) y agrega los tres archivos `.swift`
   (reemplaza el `ContentView.swift` generado).
2. En **Target › Info** agrega las claves de `Info_plist_fragmento.xml`
   (`App Transport Security Settings › Allows Local Networking = YES` y
   `Privacy - Local Network Usage Description`).
3. Carga y ejecuta en la Pico W el servidor MicroPython del servo (ver sección anterior).
4. Conecta el iPhone (o el simulador de la Mac) a la **misma red WiFi** que la Pico W.
5. Abre la app, escribe la IP que muestra la Pico W y toca **Conectar**.
   El servo se mueve al soltar el slider o con los botones 0° / 90° / 180°.

Requisitos: Xcode 15+ e iOS 16+.
