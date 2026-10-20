# Reporte Técnico: Práctica 12 — Internet de las Cosas con Aplicaciones Móviles Parte 2: WiFi
## Universidad Iberoamericana CDMX — Ingeniería Mecatrónica y Sistemas Ciberfísicos
**Materia:** Aplicaciones Móviles y Laboratorio  
**Profesor:** M. en I., MBA Omar Vázquez González  
**Alumno:** Sebastián de Jesús Enguilo Ruiz  
**Fecha de Entrega:** 20 de octubre de 2026  
**Archivo de Entrega Oficial:** `P12_Enguilo_Sebastian.pdf`  

---

## 1. Descripción Técnica y Marco Teórico

### 1.1 Fundamentos Teóricos y Arquitectura
En el paradigma del **Internet de las Cosas (IoT)**, la convergencia entre microcontroladores embebidos de bajo consumo y aplicaciones móviles reactivas constituye una de las arquitecturas más demandadas en la ingeniería contemporánea. Esta práctica aborda el desarrollo integral de un sistema ciberfísico distribuido donde una **Raspberry Pi Pico W** ejecuta un servidor HTTP ligero en **MicroPython** conectado en modalidad **Station (STA)** a una red de área local inalámbrica (WLAN), interactuando de manera bidireccional con una aplicación nativa para **iOS** desarrollada en **SwiftUI** sobre un dispositivo físico **iPhone 16 Pro Max**.

```
+-------------------------------------------------------------------------------------------------+
|                                 ARQUITECTURA DEL SISTEMA IOT                                    |
+-------------------------------------------------------------------------------------------------+
|                                                                                                 |
|   +--------------------------+       Red WiFi Local 2.4 GHz       +-------------------------+   |
|   |   iPhone 16 Pro Max      |           (SSID: Otoño26)          |  Raspberry Pi Pico W    |   |
|   |                          |                                    |                         |   |
|   |   +------------------+   |   GET /led/on                      |   +-----------------+   |   |
|   |   | ContentView      |   |   ----------------------------->   |   | Servidor Socket |   |   |
|   |   +--------+---------+   |                                    |   | Puerto 80 (HTTP)|   |   |
|   |            | Binding     |   JSON Response                    |   +--------+--------+   |   |
|   |   +--------v---------+   |   <-----------------------------   |            | Control    |   |
|   |   | ControlViewModel |   |   {"led":true,"servo":90,...}      |            | GPIO       |   |
|   |   +--------+---------+   |                                    |   +--------v--------+   |   |
|   |            | async       |   GET /servo?grados=180            |   | Actuadores:     |   |   |
|   |   +--------v---------+   |   ----------------------------->   |   | - LED (GP16)    |   |   |
|   |   | PicoAPI          |   |                                    |   | - SG90 (GP15)   |   |   |
|   |   | (URLSession)     |   |   JSON Response                    |   +-----------------+   |   |
|   |   +------------------+   |   <-----------------------------   |                         |   |
|   +--------------------------+                                    +-------------------------+   |
+-------------------------------------------------------------------------------------------------+
```

#### A. MicroPython en el microcontrolador RP2040-W
La Raspberry Pi Pico W incorpora el circuito integrado **RP2040** (doble núcleo ARM Cortex-M0+ a 133 MHz con 264 KB de SRAM interna) acoplado a un módulo de radiofrecuencia **Infineon CYW43439**, el cual provee soporte inalámbrico IEEE 802.11 b/g/n en la banda de 2.4 GHz. MicroPython compila dinámicamente un subconjunto optimizado de Python 3, permitiendo gestionar el hardware mediante librerías nativas como `machine` (para el control de temporizadores, pines GPIO y modulación por ancho de pulso PWM) y `network` (para la gestión del enlace inalámbrico de radio y la pila TCP/IP).

#### B. Modos de Operación WiFi: Station (STA) vs. Access Point (AP)
En la especificación IEEE 802.11, un dispositivo puede comportarse como:
1. **Access Point (AP):** El microcontrolador crea su propio punto de acceso autónomo, asignando direcciones IP a los clientes que se asocien a él.
2. **Station (STA):** El microcontrolador se asocia a un enrutador o punto de acceso preexistente en la infraestructura de red compartida. En esta práctica se utiliza el modo **STA**, permitiendo que tanto la Pico W como el dispositivo móvil coexistan dentro del mismo segmento de red local (`172.22.44.0/22`), facilitando el acceso simultáneo a Internet y servicios locales.

#### C. Servidor HTTP Embebido basado en Sockets BSD
El servidor implementado en `ej4_servo_wifi.py` utiliza la interfaz estándar de sockets de Berkeley. El socket se enlaza a la dirección comodín `0.0.0.0` en el puerto `80`. Al recibir un paquete de sincronización TCP y aceptar la conexión (`accept`), extrae la cabecera HTTP de la petición, segmenta el camino de la URI y los parámetros de consulta (*Query String*), ejecuta la acción en los pines físicos correspondientes y retorna una respuesta con código de estado `200 OK`, cabeceras de control de acceso cruzado (`Access-Control-Allow-Origin: *`) y un cuerpo estructurado en formato JSON.

#### D. Modulación por Ancho de Pulso (PWM) para Servomotores
Los servomotores estándar como el micro-servo SG90 requieren una señal periódica con una frecuencia constante de 50 Hz (un periodo $T = 20\text{ ms}$). La posición angular (de 0° a 180°) queda determinada exclusivamente por la duración del pulso en nivel alto ($t_{\text{alto}}$):
* **0°:** Pulso de $\sim 500\ \mu\text{s}$ ($0.5\text{ ms}$).
* **90° (Centro):** Pulso de $\sim 1500\ \mu\text{s}$ ($1.5\text{ ms}$).
* **180°:** Pulso de $\sim 2500\ \mu\text{s}$ ($2.5\text{ ms}$).

En MicroPython sobre el RP2040, la modulación PWM se cuantifica en una escala de 16 bits sin signo ($0$ a $65535$). Por lo tanto, el ciclo de trabajo de 16 bits se computa analíticamente como:
$$\text{duty\_u16} = \left\lfloor \frac{t_{\text{pulso}}(\mu\text{s}) \times 65535}{20000\ \mu\text{s}} \right\rfloor$$

#### E. Arquitectura MVVM y Concurrencia Moderna en SwiftUI
La aplicación iOS implementa el patrón de diseño **Model-View-ViewModel (MVVM)**:
* **Model (`PicoAPI` / `EstadoPico`):** Abstrae las llamadas a la red utilizando `URLSession` con configuración efímera para inhibir cachés no deseadas. Implementa el protocolo `Codable` para parsear automáticamente el JSON recibido y `Sendable` para garantizar la seguridad de memoria entre hilos.
* **ViewModel (`ControlViewModel`):** Diseñado con el atributo `@MainActor` y adherido al protocolo `ObservableObject`. Expone propiedades `@Published` (`conectado`, `led`, `grados`, `ip`, `mensaje`) que emiten notificaciones en el hilo principal cada vez que su estado sufre una mutación.
* **View (`ContentView`):** Declaración puramente declarativa de la interfaz reactiva. Al interactuar con el control deslizante (*Slider*) o los botones, se disparan tareas asíncronas (`Task { await ... }`) que no bloquean la fluidez de renderizado a 120 Hz de la pantalla del iPhone 16 Pro Max.

---

### 1.2 Tutorial Técnico Paso a Paso: Despliegue y Pruebas en Dispositivo Físico

A continuación se detalla la secuencia técnica exacta realizada para llevar el proyecto desde el repositorio de código fuente hasta la ejecución física y control en tiempo real:

1. **Configuración y Detección de Hardware de la Pico W:**
   - Se conectó la Raspberry Pi Pico W mediante cable micro-USB al equipo de desarrollo en Windows, detectándose en el Administrador de Dispositivos bajo el puerto serie `COM9` (`USB VID:PID=2E8A:0005`).
   - Se instaló la herramienta CLI `mpremote` en el entorno de desarrollo mediante `pip install mpremote`.
   - Se configuraron los parámetros de red en `PicoW_MicroPython/config.py`: SSID `Otoño26`, contraseña `Oto$o20261B3ro` y país `MX`.

2. **Carga y Verificación del Firmware MicroPython:**
   - Se transfirieron los tres módulos al sistema de archivos flash de la placa:
     ```powershell
     python -m mpremote connect COM9 fs cp PicoW_MicroPython/config.py :config.py
     python -m mpremote connect COM9 fs cp PicoW_MicroPython/wifi_conexion.py :wifi_conexion.py
     python -m mpremote connect COM9 fs cp PicoW_MicroPython/ej4_servo_wifi.py :main.py
     ```
   - Al almacenar el servidor como `main.py`, la Pico W garantiza su ejecución autónoma tan pronto como se energice, sin necesidad de conexión con la computadora.
   - En la consola de depuración se verificó la conexión exitosa:
     ```text
     Conectando a Otoño26 ...
     Conectado. IP: 172.22.46.27
     Servidor listo. Abre en el navegador: http://172.22.46.27/
     ```

3. **Creación del Proyecto en Xcode:**
   - En macOS, se creó un nuevo proyecto de tipo **iOS App** con interfaz **SwiftUI** y lenguaje **Swift** denominado `P12ControlWifi`.
   - Se agregaron los archivos de código fuente: `P12ControlWifiApp.swift` (archivo de punto de entrada con la anotación `@main`), `ContentView.swift`, `ControlViewModel.swift` y `PicoAPI.swift`.

4. **Solución de Incidencias de Compilación en Swift:**
   - Se resolvió el error de conformidad con `ObservableObject` y `@Published` en `ControlViewModel.swift` agregando las importaciones requeridas de los módulos `SwiftUI` y `Combine`, e inicializando explícitamente el valor por defecto de la propiedad `ip`.
   - Se solucionó el fallo del enlazador `Undefined symbol: _main` creando el archivo `P12ControlWifiApp.swift` con la anotación estructural `@main`.

5. **Configuración de Permisos en el Target de iOS (`Info.plist`):**
   - Dado que la Pico W responde a través de peticiones HTTP no encriptadas sobre la red local, el subsistema de seguridad *App Transport Security (ATS)* de Apple bloquea dichas transferencias por defecto.
   - En *Target > Info > Custom iOS Target Properties*, se agregaron las siguientes directivas:
     * `App Transport Security Settings` (Dictionary) $\rightarrow$ `Allow Arbitrary Loads` (Boolean) = `YES`.
     * `Privacy - Local Network Usage Description` (String) = `"La app se conecta a la Raspberry Pi Pico W en tu red WiFi para controlar el LED y el servomotor."`

6. **Aprovisionamiento y Despliegue en iPhone 16 Pro Max:**
   - Se habilitó el **Modo Desarrollador** en el dispositivo móvil (*Ajustes > Privacidad y seguridad > Modo de desarrollo*), completando el reinicio requerido.
   - Se conectó el iPhone 16 Pro Max a la Mac mediante cable USB-C, autorizando la confianza entre equipos.
   - En Xcode, se seleccionó el equipo personal de firma (*Personal Team*) y se autorizó el acceso a la clave privada de desarrollo en el Llavero (*Keychain*) para la utilidad `codesign`.
   - Se seleccionó el dispositivo físico y se compiló (`Cmd + R`).
   - En el iPhone, se confió en el perfil de desarrollo en *Ajustes > General > VPN y gestión de dispositivos*.

7. **Ejecución y Control de la Planta Física:**
   - Con el iPhone conectado a la red `Otoño26`, se abrió la aplicación `P12ControlWifi`.
   - Se aceptó el permiso modal de acceso a la red local.
   - Se introdujo la dirección IP de la Pico W (`172.22.46.27`) y se presionó **Conectar**.
   - Se validó el encendido/apagado del LED y el giro angular del servomotor en 0°, 90° y 180°.

---

## 2. Código Fuente Implementado

### 2.1 Archivo: `P12ControlWifiApp.swift`
```swift
// ==============================================================================
// Archivo: P12ControlWifiApp.swift
// Descripción: Punto de entrada principal ejecutable de la aplicación SwiftUI
// ==============================================================================

import SwiftUI

/// Estructura principal anotada con @main que define el ciclo de vida de la aplicación.
@main
struct P12ControlWifiApp: App {
    var body: some Scene {
        WindowGroup {
            // Instanciación de la vista raíz
            ContentView()
        }
    }
}
```

### 2.2 Archivo: `ContentView.swift`
```swift
// ==============================================================================
// Archivo: ContentView.swift
// Descripción: Interfaz reactiva SwiftUI para control WiFi de actuadores
// ==============================================================================

import SwiftUI

struct ContentView: View {

    // Instancia única del ViewModel que sobrevive a los ciclos de redibujado de la vista
    @StateObject private var vm = ControlViewModel()

    var body: some View {
        NavigationStack {
            Form {
                seccionConexion
                seccionLED
                seccionServo
                Section("Última respuesta de la Pico W") {
                    Text(vm.ultimaRespuesta)
                        .font(.caption.monospaced())
                }
            }
            .navigationTitle("P12 · Control WiFi")
        }
    }

    // MARK: - Sección de Conexión
    private var seccionConexion: some View {
        Section("Raspberry Pi Pico W") {
            TextField("IP, p. ej. 192.168.43.120", text: $vm.ip)
                .keyboardType(.numbersAndPunctuation)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            Button {
                Task { await vm.conectar() }
            } label: {
                Label(vm.conectado ? "Actualizar estado" : "Conectar", systemImage: "wifi")
            }
            .disabled(vm.ocupado || vm.ip.isEmpty)

            HStack(spacing: 8) {
                Circle()
                    .fill(vm.conectado ? Color.green : Color.red)
                    .frame(width: 10, height: 10)
                Text(vm.mensaje)
                    .font(.footnote)
                if vm.ocupado { ProgressView() }
            }
        }
    }

    // MARK: - Sección de Control de LED
    private var seccionLED: some View {
        Section("LED · ejercicio 3") {
            HStack(spacing: 16) {
                Image(systemName: vm.led ? "lightbulb.fill" : "lightbulb")
                    .font(.largeTitle)
                    .foregroundStyle(vm.led ? Color.yellow : Color.gray)
                Text(vm.led ? "ENCENDIDO" : "APAGADO")
                    .font(.headline)
            }
            HStack {
                Button("Encender") { Task { await vm.cambiarLED(encender: true) } }
                    .buttonStyle(.borderedProminent)
                Spacer()
                Button("Apagar") { Task { await vm.cambiarLED(encender: false) } }
                    .buttonStyle(.bordered)
            }
        }
        .disabled(!vm.conectado)
    }

    // MARK: - Sección de Control de Servomotor
    private var seccionServo: some View {
        Section("Servomotor · ejercicio 4") {
            Text("\(Int(vm.grados))°")
                .font(.system(size: 44, weight: .bold, design: .rounded))
                .frame(maxWidth: .infinity)

            HStack {
                Text("0°").font(.caption)
                // Se envía el requerimiento únicamente al liberar el slider para no congestionar el socket
                Slider(value: $vm.grados, in: 0...180, step: 1, onEditingChanged: { editando in
                    if !editando {
                        let destino = Int(vm.grados)
                        Task { await vm.moverServo(a: destino) }
                    }
                })
                Text("180°").font(.caption)
            }

            HStack {
                ForEach([0, 90, 180], id: \.self) { posicion in
                    Button("\(posicion)°") { Task { await vm.moverServo(a: posicion) } }
                        .buttonStyle(.bordered)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .disabled(!vm.conectado)
    }
}
```

### 2.3 Archivo: `ControlViewModel.swift`
```swift
// ==============================================================================
// Archivo: ControlViewModel.swift
// Descripción: Capa de lógica de negocio y gestión de estado (MVVM)
// ==============================================================================

import Foundation
import SwiftUI
import Combine

@MainActor
final class ControlViewModel: ObservableObject {

    // Persistencia automática de la dirección IP en el almacenamiento de usuario
    @Published var ip: String = UserDefaults.standard.string(forKey: "ipPicoW") ?? "" {
        didSet { UserDefaults.standard.set(ip, forKey: "ipPicoW") }
    }
    @Published var conectado = false
    @Published var ocupado = false
    @Published var led = false
    @Published var grados: Double = 90
    @Published var mensaje = "Escribe la IP de la Pico W y toca Conectar"
    @Published var ultimaRespuesta = "—"

    private let api = PicoAPI()

    init() {
        self.ip = UserDefaults.standard.string(forKey: "ipPicoW") ?? ""
    }

    // MARK: - Métodos de Operación
    func conectar() async { await ejecutar("/estado") }
    func cambiarLED(encender: Bool) async { await ejecutar(encender ? "/led/on" : "/led/off") }
    func moverServo(a valor: Int) async {
        let limitado = min(max(valor, 0), 180)
        await ejecutar("/servo?grados=\(limitado)")
    }

    // MARK: - Ejecución Centralizada de Peticiones
    private func ejecutar(_ ruta: String) async {
        ocupado = true
        defer { ocupado = false }

        do {
            let estado = try await api.pedir(ip: ip, ruta: ruta)
            led = estado.led
            grados = Double(estado.servo)
            conectado = true
            mensaje = "Conectado a la Pico W (\(estado.ip))"
            ultimaRespuesta = "GET \(ruta)\n→ led: \(estado.led), servo: \(estado.servo)°"
        } catch let error as URLError {
            conectado = false
            mensaje = explicar(error)
            ultimaRespuesta = "GET \(ruta)\n→ URLError \(error.code.rawValue)"
        } catch {
            conectado = false
            mensaje = error.localizedDescription
            ultimaRespuesta = "GET \(ruta)\n→ \(error.localizedDescription)"
        }
    }

    private func explicar(_ error: URLError) -> String {
        switch error.code {
        case .timedOut:
            return "Tiempo agotado. ¿La Mac o el iPhone están en la MISMA red WiFi que la Pico W?"
        case .cannotConnectToHost, .cannotFindHost:
            return "La IP \(ip) no responde. ¿Está corriendo main.py en la Pico W?"
        case .notConnectedToInternet, .networkConnectionLost:
            return "Este dispositivo no tiene red WiFi activa."
        case .appTransportSecurityRequiresSecureConnection:
            return "iOS bloqueó HTTP: falta 'Allows Local Networking' en Info.plist."
        default:
            return "Error de red: \(error.localizedDescription)"
        }
    }
}
```

### 2.4 Archivo: `PicoAPI.swift`
```swift
// ==============================================================================
// Archivo: PicoAPI.swift
// Descripción: Capa de red desacoplada con URLSession asíncrona
// ==============================================================================

import Foundation

/// Modelo de datos que decodifica la respuesta JSON provista por la Pico W
struct EstadoPico: Codable, Equatable, Sendable {
    let led: Bool
    let servo: Int
    let ip: String
}

enum ErrorPico: LocalizedError {
    case ipInvalida
    case respuestaHTTP(Int)

    var errorDescription: String? {
        switch self {
        case .ipInvalida:
            return "La IP no es válida. Ejemplo: 192.168.43.120"
        case .respuestaHTTP(let codigo):
            return "La Pico W respondió con error HTTP \(codigo)"
        }
    }
}

final class PicoAPI: Sendable {
    private let sesion: URLSession

    init() {
        let configuracion = URLSessionConfiguration.ephemeral
        configuracion.timeoutIntervalForRequest = 4
        configuracion.waitsForConnectivity = false
        sesion = URLSession(configuration: configuracion)
    }

    func pedir(ip: String, ruta: String) async throws -> EstadoPico {
        let ipLimpia = ip.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !ipLimpia.isEmpty,
              let url = URL(string: "http://\(ipLimpia)\(ruta)") else {
            throw ErrorPico.ipInvalida
        }

        let (datos, respuesta) = try await sesion.data(from: url)

        if let http = respuesta as? HTTPURLResponse, http.statusCode != 200 {
            throw ErrorPico.respuestaHTTP(http.statusCode)
        }
        return try JSONDecoder().decode(EstadoPico.self, from: datos)
    }
}
```

### 2.5 Archivo: `PicoW_MicroPython/ej4_servo_wifi.py` (`main.py`)
```python
# ==============================================================================
# Archivo: ej4_servo_wifi.py (guardado en la placa como main.py)
# Descripción: Servidor de sockets MicroPython para control de PWM y GPIO por HTTP
# ==============================================================================

import socket
import json
from machine import Pin, PWM
from wifi_conexion import conectar

# Configuración del pin del LED de estado
led = Pin(16, Pin.OUT)
led.off()

# Configuración del servomotor SG90 sobre el pin GP15 mediante PWM a 50 Hz
servo = PWM(Pin(15))
servo.freq(50)
PULSO_MIN_US = 500        # Ancho de pulso correspondiente a 0 grados
PULSO_MAX_US = 2500       # Ancho de pulso correspondiente a 180 grados
posicion = 90

def mover_servo(grados):
    global posicion
    grados = max(0, min(180, grados))
    pulso_us = PULSO_MIN_US + (PULSO_MAX_US - PULSO_MIN_US) * grados / 180
    servo.duty_u16(int(pulso_us * 65535 / 20000))
    posicion = grados

mover_servo(posicion)

def responder(cliente, codigo, cuerpo, tipo="application/json"):
    textos = {200: "OK", 400: "Bad Request", 404: "Not Found"}
    encabezado = ("HTTP/1.1 {} {}\r\nContent-Type: {}; charset=utf-8\r\n"
                  "Access-Control-Allow-Origin: *\r\nConnection: close\r\n\r\n").format(codigo, textos[codigo], tipo)
    cliente.sendall(encabezado.encode())
    cliente.sendall(cuerpo.encode())

def separar_ruta(ruta):
    if "?" in ruta:
        camino, consulta = ruta.split("?", 1)
    else:
        camino, consulta = ruta, ""
    parametros = {}
    for par in consulta.split("&"):
        if "=" in par:
            clave, valor = par.split("=", 1)
            parametros[clave] = valor
    return camino, parametros

def estado_json():
    return json.dumps({"led": led.value() == 1, "servo": posicion, "ip": ip})

# Inicialización de la conexión de red Station
ip = conectar()

direccion = socket.getaddrinfo("0.0.0.0", 80)[0][-1]
servidor = socket.socket()
servidor.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
servidor.bind(direccion)
servidor.listen(2)
print("Servidor listo. Abre en el navegador: http://{}/".format(ip))

try:
    while True:
        cliente, origen = servidor.accept()
        cliente.settimeout(3)
        try:
            peticion = cliente.recv(1024).decode()
            linea = peticion.split("\r\n")[0]
            partes = linea.split(" ")
            camino, parametros = separar_ruta(partes[1] if len(partes) > 1 else "/")

            if camino == "/":
                responder(cliente, 200, "<h1>Servidor Pico W Activo</h1>", "text/html")
            elif camino == "/estado":
                responder(cliente, 200, estado_json())
            elif camino == "/led/on":
                led.on()
                responder(cliente, 200, estado_json())
            elif camino == "/led/off":
                led.off()
                responder(cliente, 200, estado_json())
            elif camino == "/servo":
                try:
                    mover_servo(int(parametros.get("grados", "")))
                    responder(cliente, 200, estado_json())
                except ValueError:
                    responder(cliente, 400, json.dumps({"error": "usa /servo?grados=0..180"}))
            else:
                responder(cliente, 404, json.dumps({"error": "ruta no encontrada"}))
        except OSError as e:
            print("Conexión descartada:", e)
        finally:
            cliente.close()
except KeyboardInterrupt:
    servidor.close()
    led.off()
    servo.deinit()
```

---

## 3. Pruebas de Escritorio Analíticas

### Prueba 1: Inicialización y Conexión de Red en el iPhone 16 Pro Max
**Objetivo:** Verificar la resolución DNS, enlace WiFi local y handshake HTTP inicial `/estado`.

| Paso | Acción del Usuario | Estado del ViewModel (`vm`) | Respuesta del Hardware | Resultado en Pantalla |
| :---: | :--- | :--- | :--- | :--- |
| **1** | Apertura de la app en iOS | `ip = ""`, `conectado = false` | Pico W a la espera en puerto 80 | Formulario listo, círculo rojo |
| **2** | Ingreso de `172.22.46.27` y pulsar "Conectar" | `ocupado = true`, llamada a `GET /estado` | Pico procesa socket y responde JSON | Indicador pasa a color verde y se actualiza telemetría |

![App Instalada](imagenes/01_app_instalada_iphone.png)  
*Figura 1: Lanzamiento de la app P12ControlWifi en iPhone 16 Pro Max.*

---

### Prueba 2: Conmutación Remota del Diodo LED (Encendido y Apagado)
**Objetivo:** Comprobar la alteración del nivel lógico en el pin GP16 de la Pico W y su retroalimentación reactiva en SwiftUI.

| Paso | Acción del Usuario | Requerimiento HTTP | Nivel GP16 | Estado Visual en la App |
| :---: | :--- | :--- | :---: | :--- |
| **1** | Pulsar botón "Encender" | `GET http://172.22.46.27/led/on` | Nivel Alto ($3.3\text{ V}$) | Icono cambia a foco amarillo, etiqueta "ENCENDIDO" |
| **2** | Pulsar botón "Apagar" | `GET http://172.22.46.27/led/off` | Nivel Bajo ($0\text{ V}$) | Icono cambia a gris, etiqueta "APAGADO" |

![LED Prendido](imagenes/03_led_prendido.png)  
*Figura 2: Verificación de encendido del diodo LED en la interfaz móvil y en la planta física.*

---

### Prueba 3: Modulación Angular del Servomotor SG90 (0°, 90° y 180°)
**Objetivo:** Verificar la respuesta angular mecánica del servomotor al modificar el ciclo de trabajo del PWM desde la aplicación móvil.

| Posición Deseada | Requerimiento HTTP | Ancho de Pulso ($t_{\text{pulso}}$) | Ciclo de Trabajo (`duty_u16`) | Orientación del Brazo Mecánico |
| :---: | :--- | :---: | :---: | :--- |
| **0°** | `GET /servo?grados=0` | $500\ \mu\text{s}$ | $1638$ | Brazo posicionado hacia el extremo inferior izquierdo |
| **90°** | `GET /servo?grados=90` | $1500\ \mu\text{s}$ | $4915$ | Brazo perpendicular en posición neutra central |
| **180°** | `GET /servo?grados=180` | $2500\ \mu\text{s}$ | $8191$ | Brazo orientado hacia el extremo inferior derecho |

![Servo 180 Grados](imagenes/06_servo_180_grados.png)  
*Figura 3: Posicionamiento del servomotor a 180 grados con telemetría JSON de confirmación.*

---

## 4. Galería Integral de Evidencias

### Evidencia 4.1: Instalación en iPhone 16 Pro Max
![01 App Instalada](imagenes/01_app_instalada_iphone.png)  
*Figura 4.1: Aplicación P12ControlWifi debidamente compilada, firmada y accesible en el sistema operativo iOS.*

### Evidencia 4.2: Enlace Establecido y LED Apagado
![02 LED Apagado](imagenes/02_led_apagado.png)  
*Figura 4.2: Conexión exitosa a la IP 172.22.46.27 con estado inicial del diodo LED apagado en el protoboard.*

### Evidencia 4.3: Comando de Encendido de LED por WiFi
![03 LED Prendido](imagenes/03_led_prendido.png)  
*Figura 4.3: Conmutación a nivel alto del pin GP16; se observa el encendido físico del LED y la actualización del estado a ENCENDIDO.*

### Evidencia 4.4: Calibración y Posición Centrada del Servomotor (90°)
![04 Servo 90 Grados](imagenes/04_servo_90_grados.png)  
*Figura 4.4: Envío del comando de 90 grados y verificación de posicionamiento del servomotor en la planta física.*

### Evidencia 4.5: Servomotor Comandado al Extremo Mínimo (0°)
![05 Servo 0 Grados](imagenes/05_servo_0_grados.png)  
*Figura 4.5: Desplazamiento del actuador mecánico a 0 grados ante el evento de interfaz.*

### Evidencia 4.6: Servomotor Comandado al Extremo Máximo (180°)
![06 Servo 180 Grados](imagenes/06_servo_180_grados.png)  
*Figura 4.6: Desplazamiento del actuador mecánico al ángulo límite de 180 grados y captura del payload JSON devuelto.*

### Evidencia 4.7: Manejo de Excepciones y Pérdida de Conexión
![07 Manejo Error Red](imagenes/07_manejo_error_red_timeout.png)  
*Figura 4.7: Gestión de errores URLError.timedOut que alerta al usuario cuando existe pérdida de conectividad en la red.*

### Evidencia 4.8: Montaje Completo del Circuito y Planta Física
![08 Planta Fisica](imagenes/08_planta_fisica_circuito_pico_w.png)  
*Figura 4.8: Circuito completo sobre protoboard: Raspberry Pi Pico W, conexiones de alimentación a 5 V (VBUS), masa común y servomotor SG90.*

---

## 5. Conclusiones Técnicas

> ### Conclusiones y Análisis de Ingeniería de Software
> **Síntesis del Aprendizaje y Rendimiento:**  
> La implementación de esta práctica permitió consolidar la integración de arquitecturas IoT extremo a extremo, uniendo el cómputo embebido de tiempo real en microcontroladores con la ingeniería de software móvil moderna. La elección de **MicroPython** en la Raspberry Pi Pico W facilitó un desarrollo ágil para el manejo de la pila TCP/IP y el temporizado de pulsos PWM, demostrando que un microcontrolador de bajo costo puede desempeñarse eficazmente como servidor HTTP ligero para aplicaciones de monitoreo y control ciberfísico.  
> Por su parte, en el ecosistema **iOS con SwiftUI**, la aplicación del patrón **MVVM** desacopló de manera limpia la capa de red (`PicoAPI`) de la renderización reactiva (`ContentView`). El uso de `URLSession` con configuración efímera y primitivas modernas de concurrencia estructurada (`async/await`, `@MainActor`) previno bloqueos en la interfaz de usuario, garantizando una tasa de refresco fluida de 120 cuadros por segundo en el iPhone 16 Pro Max. Asimismo, la resolución de requerimientos de seguridad como la configuración de directivas en *App Transport Security* (`NSAllowsLocalNetworking` / `NSAllowsArbitraryLoads`) y la gestión de permisos en tiempo de ejecución para el escaneo de red local evidenciaron los estándares estrictos de privacidad que rigen en los sistemas operativos móviles actuales. En conclusión, la solución obtenida es sumamente robusta, modular, tolerante a fallos de red y directamente extrapolable a sistemas de telemetría y domótica industrial.
