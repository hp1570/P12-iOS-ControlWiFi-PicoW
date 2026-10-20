//  ContentView.swift
//  P12 · Interfaz SwiftUI: conexión, LED (ejercicio 3) y servomotor (ejercicio 4) por WiFi.

import SwiftUI

struct ContentView: View {

    // @StateObject: la vista crea el ViewModel una sola vez y lo conserva entre redibujados.
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

    // MARK: - Conexión

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

    // MARK: - LED

    private var seccionLED: some View {
        Section("LED · ejercicio 3") {
            HStack(spacing: 16) {
                Image(systemName: vm.led ? "lightbulb.fill" : "lightbulb")
                    .font(.largeTitle)
                    .foregroundStyle(vm.led ? Color.yellow : Color.gray)
                Text(vm.led ? "ENCENDIDO" : "APAGADO")
                    .font(.headline)
            }
            // En un Form, varios botones en la misma fila necesitan un buttonStyle explícito;
            // si no, al tocar uno se disparan todos los de la fila.
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

    // MARK: - Servo

    private var seccionServo: some View {
        Section("Servomotor · ejercicio 4") {
            Text("\(Int(vm.grados))°")
                .font(.system(size: 44, weight: .bold, design: .rounded))
                .frame(maxWidth: .infinity)

            HStack {
                Text("0°").font(.caption)
                // El comando se envía al SOLTAR el slider (editando == false), no en cada movimiento:
                // así no se satura a la Pico W con decenas de peticiones por segundo.
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

// Vista previa en el Canvas de Xcode (Editor > Canvas)
struct ContentView_Previews: PreviewProvider {
    static var previews: some View { ContentView() }
}
