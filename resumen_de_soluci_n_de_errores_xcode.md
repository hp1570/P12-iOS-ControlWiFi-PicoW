# Bitácora de Solución de Errores: Proyecto P12ControlWifi

Este documento resume los pasos y soluciones aplicadas para resolver la cadena de errores surgidos durante la configuración, compilación, firma y ejecución del proyecto en Xcode, SwiftUI y el dispositivo físico.

---

## 1. Error de Conformidad con `ObservableObject` y `@Published`

### Síntomas observados
* `Type 'ControlViewModel' does not conform to protocol 'ObservableObject'`
* `Initializer 'init(wrappedValue:)' is not available due to missing import of defining module...`

### Causa raíz
1. Faltaba importar el módulo correspondiente (`Combine` o `SwiftUI`), necesarios para reconocer el protocolo `ObservableObject` y el *property wrapper* `@Published`.
2. La propiedad `@Published var ip: String` no contaba con un valor inicial definido, lo cual provocaba un fallo en la síntesis automática del inicializador de `@Published`.

### Solución aplicada
1. Se agregaron los módulos al inicio del archivo:
   ```swift
   import SwiftUI
   import Combine
   ```
2. Se le asignó un valor inicial explícito a la propiedad `ip` para permitir su inicialización:
   ```swift
   @Published var ip: String = UserDefaults.standard.string(forKey: "ipPicoW") ?? "" {
       didSet { UserDefaults.standard.set(ip, forKey: "ipPicoW") }
   }
   ```

---

## 2. Error del Enlazador: `Undefined symbol: _main`

### Síntomas observados
* `Undefined symbol: _main`
* `Linker command failed with exit code 1`

### Causa raíz
El archivo raíz de arranque de la aplicación (`P12ControlWifiApp.swift`) había sido eliminado por error, por lo que el compilador no encontró la anotación `@main` que define el punto de entrada ejecutable.

### Solución aplicada
1. Se creó nuevamente el archivo:
   * **Ruta / Nombre:** `P12ControlWifiApp.swift`
   * **Target:** Se verificó que perteneciera a `P12ControlWifi`.
2. Se reincorporó la estructura principal de ciclo de vida de SwiftUI:
   ```swift
   import SwiftUI

   @main
   struct P12ControlWifiApp: App {
       var body: some Scene {
           WindowGroup {
               ContentView()
           }
       }
   }
   ```
3. Se limpió la memoria intermedia del proyecto con **`Cmd + Shift + K`** (*Clean Build Folder*) y se compiló de nuevo con **`Cmd + B`**.

---

## 3. Autorización de Firma de Código (`codesign`) en Llavero

### Síntoma observado
* Ventana modal del sistema: `codesign wants to access key "Apple Development: ..." in your keychain.`

### Causa raíz
La utilidad de compilación de macOS (`codesign`) requiere acceder al certificado y clave privada de desarrollo almacenados en el Llavero (*Keychain*) de macOS para firmar criptográficamente el binario antes de ejecutarlo en un dispositivo o simulador.

### Solución aplicada
1. Se ingresó la contraseña de inicio de sesión de usuario de la Mac.
2. Se hizo clic en el botón **Always Allow** (*Siempre permitir*) para autorizar permanentemente el acceso del compilador a la clave y evitar interrupciones recurrentes en futuras compilaciones.

---

## 4. Configuración y Confianza en Dispositivo Físico (iPhone)

Para permitir la ejecución de tu aplicación instalada desde Xcode en tu dispositivo físico, es necesario confiar en el certificado de desarrollador y tener habilitados los permisos del sistema:

### A. Confiar en el certificado de desarrollador
1. Abre **Ajustes** (*Settings*) en tu iPhone.
2. Ve a **General**.
3. Selecciona **Gestión de dispositivos y VPN** (o *Administración de dispositivos* / *VPN & Device Management*).
4. En la sección **App de desarrollador** (*Developer App*), toca el perfil correspondiente a tu cuenta:  
   `Apple Development: chucho.eng@icloud.com (T6Z43HHPMM)`.
5. Pulsa en **Confiar en "Apple Development: chucho.eng..."** y confirma seleccionando **Confiar**.

### B. Modo Desarrollador (iOS 16 o superior)
Si al abrir la app te aparece una alerta indicando que debes activar el modo de desarrollo:
1. Ve a **Ajustes** > **Privacidad y seguridad** (*Privacy & Security*).
2. Desplázate hasta el final y entra en **Modo Desarrollador** (*Developer Mode*).
3. Activa la casilla y confirma para reiniciar el dispositivo cuando lo solicite.
4. Tras reiniciar, desbloquea el iPhone y confirma en la alerta emergente seleccionando **Activar**.