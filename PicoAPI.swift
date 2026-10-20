//  PicoAPI.swift
//  P12 · App iOS que controla por WiFi la Raspberry Pi Pico W (ej4_servo_wifi.py / main.py)
//
//  Capa de red: arma la URL, hace la petición HTTP y convierte el JSON en un struct.
//  La vista nunca toca URLSession directamente.
//
//  API de la Pico W (todas GET, todas responden el mismo JSON de estado):
//    /estado             -> {"led": false, "servo": 90, "ip": "192.168.x.x"}
//    /led/on   /led/off
//    /servo?grados=0..180

import Foundation

/// Lo que responde la Pico W. Codable permite decodificar el JSON automáticamente:
/// los nombres de las propiedades coinciden con las claves del JSON.
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

/// Sendable: solo tiene una constante (URLSession ya es segura entre hilos), así que puede usarse
/// desde el ViewModel (@MainActor) sin advertencias de concurrencia.
final class PicoAPI: Sendable {

    private let sesion: URLSession

    init() {
        // .ephemeral: sin caché ni cookies (cada petición debe llegar de verdad a la Pico).
        let configuracion = URLSessionConfiguration.ephemeral
        configuracion.timeoutIntervalForRequest = 4      // Si en 4 s no responde, se reporta error
        configuracion.waitsForConnectivity = false       // Falla rápido en lugar de esperar a que "haya red"
        sesion = URLSession(configuration: configuracion)
    }

    /// Hace GET http://<ip><ruta> y devuelve el estado decodificado.
    func pedir(ip: String, ruta: String) async throws -> EstadoPico {
        let ipLimpia = ip.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !ipLimpia.isEmpty,
              let url = URL(string: "http://\(ipLimpia)\(ruta)") else {
            throw ErrorPico.ipInvalida
        }

        // async/await: la función se "pausa" aquí sin bloquear la interfaz hasta que llega la respuesta.
        let (datos, respuesta) = try await sesion.data(from: url)

        if let http = respuesta as? HTTPURLResponse, http.statusCode != 200 {
            throw ErrorPico.respuestaHTTP(http.statusCode)
        }
        return try JSONDecoder().decode(EstadoPico.self, from: datos)
    }
}
