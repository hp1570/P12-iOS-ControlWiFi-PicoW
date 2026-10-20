# Módulo reutilizable: misma lógica del ejercicio 2, empaquetada en una función.
# Lo usan ej3 y ej4. Guárdalo EN LA PICO W junto con config.py.

import network
import time
from machine import Pin
import config


def conectar(limite_s=20):
    try:
        network.country(config.PAIS)
    except AttributeError:
        import rp2
        rp2.country(config.PAIS)

    wlan = network.WLAN(network.STA_IF)
    wlan.active(True)
    wlan.config(pm=0xa11140)
    led = Pin("LED", Pin.OUT)

    if not wlan.isconnected():
        print("Conectando a", config.SSID, "...")
        wlan.connect(config.SSID, config.PASSWORD)
        inicio = time.time()
        while wlan.status() != 3:
            if wlan.status() < 0:
                raise RuntimeError("Error WiFi, estado " + str(wlan.status()))
            if time.time() - inicio > limite_s:
                raise RuntimeError("Tiempo agotado al conectar a " + config.SSID)
            led.toggle()
            time.sleep(0.5)

    led.on()
    ip = wlan.ifconfig()[0]
    print("Conectado. IP:", ip)
    return ip
