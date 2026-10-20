# P12 · Parte 2 · Ejercicio 4 (opción elegida): Control de Servomotor por WiFi
# Incluye también el LED del ejercicio 3: es el servidor que usará la app iOS.
# Para que arranque solo al conectar la Pico (sin Thonny), guárdalo en la Pico como main.py.
#
# API (todas GET, responden JSON):
#   /                    -> página de control para navegador
#   /estado              -> {"led": bool, "servo": int, "ip": str}
#   /led/on  /led/off    -> enciende / apaga el LED
#   /servo?grados=90     -> mueve el servo (0 a 180)
#
# Conexión del servo (SG90 / MOT-100):
#   señal (naranja/amarillo) -> GP15 (pin físico 20)
#   rojo  (+)                -> VBUS (pin físico 40, 5 V del USB)
#   café/negro (-)           -> GND  (pin físico 38)
# LED: GP16 (pin 21) -> 220 ohm -> LED -> GND (pin 23)

import socket
import json
from machine import Pin, PWM
from wifi_conexion import conectar

# ---------- Hardware ----------
led = Pin(16, Pin.OUT)
led.off()

servo = PWM(Pin(15))
servo.freq(50)            # Los servos esperan un pulso cada 20 ms (50 Hz)
PULSO_MIN_US = 500        # Pulso para 0°   (ajústalo si tu servo no llega al extremo o zumba)
PULSO_MAX_US = 2500       # Pulso para 180°
posicion = 90


def mover_servo(grados):
    global posicion
    grados = max(0, min(180, grados))                                  # Se limita al rango válido
    pulso_us = PULSO_MIN_US + (PULSO_MAX_US - PULSO_MIN_US) * grados / 180
    servo.duty_u16(int(pulso_us * 65535 / 20000))                      # Ancho de pulso -> ciclo de trabajo de 16 bits
    posicion = grados


mover_servo(posicion)

# ---------- HTTP ----------
PAGINA = """<!DOCTYPE html><html><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>P12 Servo WiFi</title>
<style>body{font-family:sans-serif;text-align:center;margin-top:30px}
button{font-size:20px;padding:12px 24px;margin:6px;border-radius:10px}
input{width:80%}</style></head>
<body><h2>P12 - Servomotor y LED por WiFi</h2>
<p id="e">Cargando...</p>
<h3>Servo: <span id="g">90</span>&deg;</h3>
<input type="range" min="0" max="180" value="90" id="r"
 oninput="document.getElementById('g').innerText=this.value"
 onchange="m('/servo?grados='+this.value)"><br>
<button onclick="m('/servo?grados=0')">0&deg;</button>
<button onclick="m('/servo?grados=90')">90&deg;</button>
<button onclick="m('/servo?grados=180')">180&deg;</button>
<h3>LED</h3>
<button onclick="m('/led/on')">ENCENDER</button>
<button onclick="m('/led/off')">APAGAR</button>
<script>
function m(r){fetch(r).then(x=>x.json()).then(d=>{
 document.getElementById('e').innerText='LED: '+(d.led?'ENCENDIDO':'APAGADO')+'  |  Servo: '+d.servo+' grados';
 document.getElementById('r').value=d.servo;document.getElementById('g').innerText=d.servo;})}
m('/estado');
</script></body></html>"""


def responder(cliente, codigo, cuerpo, tipo="application/json"):
    textos = {200: "OK", 400: "Bad Request", 404: "Not Found"}
    encabezado = ("HTTP/1.1 {} {}\r\nContent-Type: {}; charset=utf-8\r\n"
                  "Access-Control-Allow-Origin: *\r\nConnection: close\r\n\r\n").format(codigo, textos[codigo], tipo)
    cliente.sendall(encabezado.encode())
    cliente.sendall(cuerpo.encode())


def separar_ruta(ruta):
    # "/servo?grados=90" -> ("/servo", {"grados": "90"})
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
            print(origen[0], "->", linea)

            if camino == "/":
                responder(cliente, 200, PAGINA, "text/html")
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
    print("Servidor detenido")
