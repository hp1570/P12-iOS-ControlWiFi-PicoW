//  ControlViewModel.swift
//  P12 · Estado de la pantalla y lógica (patrón MVVM).
//
//  La vista (ContentView) solo dibuja lo que hay aquí y llama a estas funciones.
//  @MainActor garantiza que todas las propiedades @Published se actualicen en el hilo
//  principal, que es el único que puede modificar la interfaz.

import Foundation

@MainActor
final class ControlViewModel: ObservableObject {

    // La IP se guarda en UserDefaults para no tener que escribirla cada vez que se abre la app.
    @Published var ip: String {
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
        ip = UserDefaults.standard.string(forKey: "ipPicoW") ?? ""
    }

    // MARK: - Acciones que llama la vista

    func conectar() async { await ejecutar("/estado") }

    func cambiarLED(encender: Bool) async { await ejecutar(encender ? "/led/on" : "/led/off") }

    func moverServo(a valor: Int) async {
        let limitado = min(max(valor, 0), 180)     // La Pico también lo limita; aquí se evita mandar basura
        await ejecutar("/servo?grados=\(limitado)")
    }

    // MARK: - Lógica común

    /// Todas las rutas responden el mismo JSON, así que una sola función actualiza toda la pantalla
    /// con lo que REALMENTE reporta la Pico (no con lo que "creemos" que pasó).
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

    /// Traduce los errores de red más comunes a una causa probable.
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
