# RedProfesional

Cliente HTTP profesional para Swift, construido sobre `URLSession` con soporte completo de async/await.

Sin dependencias externas. Compatible con iOS 17+ y macOS 14+.

---

## Instalación

### Swift Package Manager

En Xcode: **File → Add Package Dependencies** y agrega la URL de este repositorio.

O en tu `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/tu-usuario/RedProfesional.git", from: "1.0.0")
]
```

---

## Uso rápido

```swift
import RedProfesional

// 1. Configura el cliente una sola vez (p. ej. en tu capa de servicios)
var cliente = ClienteHTTP(baseURL: URL(string: "https://api.ejemplo.com")!)
cliente.token = "mi-token-bearer"

// 2. Define tus endpoints
let endpointPerfil = Endpoint(path: "usuarios/perfil")
let endpointLogin  = Endpoint(path: "auth/login", metodo: .post)

// 3. Haz peticiones
struct Perfil: Decodable {
    let id: Int
    let nombre: String
}

let perfil: Perfil = try await cliente.request(endpoint: endpointPerfil, tipo: Perfil.self)
```

---

## Métodos disponibles

### Petición con respuesta tipada

```swift
let perfil: Perfil = try await cliente.request(endpoint: .perfil, tipo: Perfil.self)
```

### Petición sin respuesta (204 / body vacío)

```swift
try await cliente.requestSinRespuesta(endpoint: .cerrarSesion)
```

### Petición con body

```swift
struct LoginBody: Encodable {
    let usuario: String
    let password: String
}

let body = LoginBody(usuario: "juan", password: "1234")
let token: TokenRespuesta = try await cliente.request(
    endpoint: Endpoint(path: "auth/login", metodo: .post),
    tipo: TokenRespuesta.self,
    body: body
)
```

### Datos crudos — para inspección o almacenamiento

```swift
// Respuesta completa: body, statusCode, headers, fecha
let respuesta: RespuestaCruda = try await cliente.requestCrudo(endpoint: .catalogo)
print(respuesta.statusCode)       // 200
print(respuesta.jsonPretty ?? "") // JSON formateado
print(respuesta.headers)          // ["Content-Type": "application/json", ...]

// Solo Data (para reenviar bytes)
let data: Data = try await cliente.requestRaw(endpoint: .catalogo)

// Solo el JSON como String legible
let json: String = try await cliente.requestJSON(endpoint: .catalogo)
print(json)
// {
//   "id": 1,
//   "nombre": "Producto A"
// }
```

### Puente a SwiftData (en tu app, fuera del paquete)

```swift
let respuesta = try await cliente.requestCrudo(endpoint: .catalogo)

// Tu @Model recibe los datos directamente
miRegistro.jsonGuardado  = respuesta.data        // Data
miRegistro.statusCode    = respuesta.statusCode  // Int
miRegistro.fechaCaptura  = respuesta.fecha       // Date
```

---

## Endpoints

```swift
// GET simple
Endpoint(path: "productos")

// Con query params → /productos?pagina=2&limite=20
Endpoint(path: "productos", query: ["pagina": "2", "limite": "20"])

// POST con timeout personalizado
Endpoint(path: "auth/login", metodo: .post, timeout: 10)

// Con headers personalizados
Endpoint(path: "archivos/subir", metodo: .put, headers: ["X-Version": "2"])
```

---

## Manejo de errores

```swift
do {
    let perfil: Perfil = try await cliente.request(endpoint: .perfil, tipo: Perfil.self)
} catch let error as ErrorRed {
    // Mensaje listo para mostrar al usuario
    print(error.mensajeUsuario)   // "Sesión no válida. Inicia sesión de nuevo."

    // Detalle técnico para logs
    print(error.detalleDebug)     // "HTTP 401 body={"error":"token_expirado"}"

    // Manejo por caso
    switch error {
    case .red(tipo: .sinInternet, _):
        // sin conexión
    case .http(codigo: 401, _):
        // redirigir al login
    case .http(codigo: let codigo, let body):
        // otro error HTTP
    case .decoding(let detalle):
        // el JSON no coincide con tu modelo
    default:
        break
    }
}
```

### Casos de `ErrorRed`

| Caso | Cuándo ocurre |
|---|---|
| `.red(tipo:)` | Fallo de red: sin internet, timeout, DNS, SSL, conexión perdida |
| `.http(codigo:body:)` | El servidor respondió con un código fuera de 2xx |
| `.decoding(detalle:)` | El JSON no pudo mapearse al tipo esperado |
| `.encoding(detalle:)` | El body no pudo serializarse a JSON |
| `.urlInvalida` | La URL construida no es válida |
| `.sinRespuestaHTTP` | La respuesta no es HTTP |
| `.desconocido(detalle:)` | Error no clasificado |

---

## Reintentos automáticos

El cliente reintenta automáticamente ante fallos de red transitorios (timeout, sin internet, DNS, conexión perdida). Los errores HTTP (4xx/5xx) **no** se reintentan por defecto.

```swift
// Configuración por defecto: 1 reintento, 0.6 s de delay base (exponencial)
cliente.politicaReintentos = PoliticaReintentos(maxReintentos: 3, baseDelay: 1.0)
// Delays: 1.0 s → 2.0 s → 4.0 s
```

---

## Logging

```swift
// Desarrollo: ver todo (default)
cliente.logger = LoggerConsola(nivelMinimo: .debug)

// Producción: solo errores
cliente.logger = LoggerConsola(nivelMinimo: .error)

// Sin logs
cliente.logger = LoggerNulo()

// Logger propio (implementa el protocolo)
struct MiLogger: LoggerRed {
    func log(_ evento: EventoLogRed) {
        // enviar a tu sistema de métricas
    }
}
cliente.logger = MiLogger()
```

Ejemplo de salida en consola:

```
[RED] 14:32:05.120 [DEBUG  ] ➡️ GET https://api.ejemplo.com/productos rid=ABC123
[RED] 14:32:05.847 [INFO   ] ✅ [200] rid=ABC123 bytes=1024
[RED] 14:32:05.848 [DEBUG  ] JSON ⬇️
{
  "id": 1,
  "nombre": "Producto A"
}
```

---

## Inspección de `Data`

El paquete extiende `Data` con dos helpers útiles en cualquier parte de tu app:

```swift
let data: Data = ...
print(data.jsonPretty ?? "no es JSON")  // JSON formateado
print(data.utf8String ?? "no es texto") // texto plano
```

---

## Configuración avanzada

```swift
// Decoder con snake_case automático
var cliente = ClienteHTTP(baseURL: url)
cliente.jsonDecoder.keyDecodingStrategy = .convertFromSnakeCase

// Encoder con fechas ISO 8601
cliente.jsonEncoder.dateEncodingStrategy = .iso8601

// URLSession personalizada (p. ej. con caché o configuración de fondo)
let config = URLSessionConfiguration.default
config.requestCachePolicy = .reloadIgnoringLocalCacheData
let cliente = ClienteHTTP(baseURL: url, session: URLSession(configuration: config))
```

---

## Requisitos

| | Versión mínima |
|---|---|
| iOS | 17.0 |
| macOS | 14.0 |
| Swift | 6.2 |

---

## Archivos del paquete

| Archivo | Responsabilidad |
|---|---|
| `ClienteHTTP.swift` | Cliente principal con toda la lógica de peticiones |
| `EndPoint.swift` | Describe una petición: ruta, método, query, headers, timeout |
| `RespuestaCruda.swift` | Respuesta completa sin decodificar: body, status, headers, fecha |
| `ErrorRed.swift` | Errores tipados con mensajes para UI y para debug |
| `LoggerRed.swift` | Protocolo de logging con implementaciones de consola y nulo |
| `PoliticaReintentos.swift` | Configuración de reintentos con backoff exponencial |
