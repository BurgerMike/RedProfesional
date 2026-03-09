//
//  ClienteHTTP.swift
//  RedProfesional
//

import Foundation

/// Cliente HTTP principal. Configura una vez y reutiliza en toda la app.
///
/// ## Uso básico
/// ```swift
/// var cliente = ClienteHTTP(baseURL: URL(string: "https://api.ejemplo.com")!)
/// cliente.token = "mi-token"
/// let usuario: Usuario = try await cliente.request(endpoint: .perfil, tipo: Usuario.self)
/// ```
///
/// ## Refresh de token automático
/// ```swift
/// cliente.manejadorToken = MiTokenManager()
/// // Si el servidor responde 401, el cliente renueva el token y reintenta solo.
/// ```
///
/// ## Interceptores
/// ```swift
/// cliente.interceptores = [VersionInterceptor(), MetricasInterceptor()]
/// ```
///
/// ## Cancelación
/// ```swift
/// let rid = UUID().uuidString
/// Task { try await cliente.request(endpoint: .catalogo, tipo: Catalogo.self, requestId: rid) }
/// cliente.cancelar(requestId: rid)
/// ```
public final class ClienteHTTP: Sendable {

    /// URL base a la que se concatenan las rutas de cada endpoint.
    public let baseURL: URL

    /// Token de autorización Bearer. Si está presente se envía en cada petición.
    /// Se actualiza automáticamente tras un refresh exitoso.
    public var token: String? {
        get { _token.value }
        set { _token.setValue(newValue) }
    }

    /// Tiempo máximo de espera cuando el endpoint no define uno propio. Por defecto: 15 s.
    public var timeoutPorDefecto: TimeInterval {
        get { _timeoutPorDefecto.value }
        set { _timeoutPorDefecto.setValue(newValue) }
    }

    /// Política de reintentos ante fallos de red transitorios.
    public var politicaReintentos: PoliticaReintentos {
        get { _politicaReintentos.value }
        set { _politicaReintentos.setValue(newValue) }
    }

    /// Logger de eventos de red.
    public var logger: (any LoggerRed)? {
        get { _logger.value }
        set { _logger.setValue(newValue) }
    }

    /// Manejador de token para refresh automático en 401.
    /// Implementa `ManejadorToken` en tu app y asígnalo aquí.
    public var manejadorToken: (any ManejadorToken)? {
        get { _manejadorToken.value }
        set { _manejadorToken.setValue(newValue) }
    }

    /// Lista de interceptores que se aplican en orden a cada petición.
    public var interceptores: [any Interceptor] {
        get { _interceptores.value }
        set { _interceptores.setValue(newValue) }
    }

    /// Decoder JSON configurable.
    public var jsonDecoder: JSONDecoder {
        get { _jsonDecoder.value }
        set { _jsonDecoder.setValue(newValue) }
    }

    /// Encoder JSON configurable.
    public var jsonEncoder: JSONEncoder {
        get { _jsonEncoder.value }
        set { _jsonEncoder.setValue(newValue) }
    }

    // MARK: - Almacenamiento thread-safe para propiedades mutables

    private let _token:              Locked<String?>                 = .init(nil)
    private let _timeoutPorDefecto:  Locked<TimeInterval>            = .init(15)
    private let _politicaReintentos: Locked<PoliticaReintentos>      = .init(.default)
    private let _logger:             Locked<(any LoggerRed)?>        = .init(LoggerConsola())
    private let _manejadorToken:     Locked<(any ManejadorToken)?>   = .init(nil)
    private let _interceptores:      Locked<[any Interceptor]>       = .init([])
    private let _jsonDecoder:        Locked<JSONDecoder>              = .init(JSONDecoder())
    private let _jsonEncoder:        Locked<JSONEncoder>              = .init(JSONEncoder())

    private let session: URLSession

    /// Tareas activas indexadas por requestId, para cancelación.
    private let tareasActivas: Locked<[String: Task<Void, Never>]> = .init([:])

    // MARK: - Init

    public init(baseURL: URL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }

    // MARK: - API principal (Decodable)

    /// Ejecuta una petición y decodifica la respuesta al tipo indicado.
    public func request<T: Decodable>(
        endpoint: Endpoint,
        tipo: T.Type,
        body: (any Encodable)? = nil,
        requestId: String = UUID().uuidString
    ) async throws -> T {

        var intento = 0
        var tokenRefrescado = false

        while true {
            do {
                var req = try construirRequest(endpoint: endpoint, body: body, requestId: requestId)

                // Aplicar interceptores (adaptar request)
                for interceptor in interceptores {
                    try await interceptor.adaptarRequest(&req)
                }

                log(.debug, "➡️ \(req.httpMethod ?? "") \(req.url?.absoluteString ?? "") rid=\(requestId)")

                let (data, response) = try await session.data(for: req)

                // Refresh token automático en 401
                if let http = response as? HTTPURLResponse,
                   http.statusCode == 401,
                   !tokenRefrescado,
                   let manejador = manejadorToken {
                    log(.info, "🔄 Token expirado, refrescando... rid=\(requestId)")
                    do {
                        let nuevoToken = try await manejador.refrescarToken()
                        token = nuevoToken
                        tokenRefrescado = true
                        log(.info, "✅ Token renovado, reintentando rid=\(requestId)")
                        continue // reintenta con el token nuevo
                    } catch {
                        log(.error, "❌ Refresh de token falló: \(error.localizedDescription) rid=\(requestId)")
                        throw ErrorRed.http(codigo: 401, body: "Token refresh falló")
                    }
                }

                let http = try validarHTTP(response: response, data: data)
                let crudo = RespuestaCruda(data: data, http: http)

                // Notificar interceptores de respuesta exitosa
                for interceptor in interceptores {
                    await interceptor.alRecibirRespuesta(crudo, de: req)
                }

                // 204 o body vacío
                if http.statusCode == 204 || data.isEmpty {
                    guard let vacia = RespuestaVacia() as? T else {
                        throw ErrorRed.decoding(detalle: "Respuesta vacía, pero se esperaba JSON para \(T.self)")
                    }
                    return vacia
                }

                let decodificado = try decodificar(T.self, data: data)

                log(.info,  "✅ \(req.httpMethod ?? "") [\(http.statusCode)] rid=\(requestId) bytes=\(data.count)")
                log(.debug, "JSON ⬇️\n\(data.jsonPretty ?? data.utf8String ?? "<binario>")")

                return decodificado

            } catch {
                let e = ErrorRed.desde(error)

                // Notificar interceptores del fallo
                if let req = try? construirRequest(endpoint: endpoint, body: body, requestId: requestId) {
                    for interceptor in interceptores {
                        await interceptor.alFallar(e, en: req)
                    }
                }

                log(.error, "❌ \(endpoint.metodo.rawValue) \(endpoint.path) rid=\(requestId)\n\(e.detalleDebug)")

                if intento < politicaReintentos.maxReintentos, politicaReintentos.debeReintentar(e) {
                    let espera = politicaReintentos.delay(paraIntento: intento)
                    intento += 1
                    log(.info, "🔁 Reintento \(intento)/\(politicaReintentos.maxReintentos) en \(String(format: "%.2f", espera))s rid=\(requestId)")
                    try? await Task.sleep(nanoseconds: UInt64(espera * 1_000_000_000))
                    continue
                }

                throw e
            }
        }
    }

    // MARK: - API sin respuesta (204 / vacío)

    /// Ejecuta una petición que no devuelve body (204 o vacío).
    public func requestSinRespuesta(
        endpoint: Endpoint,
        body: (any Encodable)? = nil,
        requestId: String = UUID().uuidString
    ) async throws {
        _ = try await request(endpoint: endpoint, tipo: RespuestaVacia.self, body: body, requestId: requestId)
    }

    // MARK: - API datos crudos

    /// Ejecuta la petición y devuelve una `RespuestaCruda` con body, status, headers y fecha.
    ///
    /// Ideal para guardar en SwiftData o inspeccionar un endpoint desconocido.
    ///
    /// ```swift
    /// let respuesta = try await cliente.requestCrudo(endpoint: .catalogo)
    /// miModelo.jsonGuardado = respuesta.data
    /// miModelo.statusCode   = respuesta.statusCode
    /// let etag = respuesta.header("ETag")
    /// ```
    public func requestCrudo(
        endpoint: Endpoint,
        body: (any Encodable)? = nil,
        requestId: String = UUID().uuidString
    ) async throws -> RespuestaCruda {
        var req = try construirRequest(endpoint: endpoint, body: body, requestId: requestId)

        for interceptor in interceptores {
            try await interceptor.adaptarRequest(&req)
        }

        log(.debug, "➡️ \(req.httpMethod ?? "") \(req.url?.absoluteString ?? "") rid=\(requestId)")

        let (data, response) = try await session.data(for: req)

        // Refresh automático en 401
        if let http = response as? HTTPURLResponse,
           http.statusCode == 401,
           let manejador = manejadorToken {
            log(.info, "🔄 Token expirado, refrescando... rid=\(requestId)")
            let nuevoToken = try await manejador.refrescarToken()
            token = nuevoToken
            return try await requestCrudo(endpoint: endpoint, body: body, requestId: requestId)
        }

        let http = try validarHTTP(response: response, data: data)
        let crudo = RespuestaCruda(data: data, http: http)

        for interceptor in interceptores {
            await interceptor.alRecibirRespuesta(crudo, de: req)
        }

        log(.info,  "✅ [\(crudo.statusCode)] rid=\(requestId) bytes=\(crudo.bytes)")
        log(.debug, "JSON ⬇️\n\(crudo.jsonPretty ?? crudo.utf8String ?? "<binario>")")

        return crudo
    }

    /// Ejecuta la petición y devuelve el `Data` crudo.
    public func requestRaw(
        endpoint: Endpoint,
        body: (any Encodable)? = nil,
        requestId: String = UUID().uuidString
    ) async throws -> Data {
        try await requestCrudo(endpoint: endpoint, body: body, requestId: requestId).data
    }

    /// Ejecuta la petición y devuelve el JSON como `String` legible (pretty-printed).
    ///
    /// ```swift
    /// let json = try await cliente.requestJSON(endpoint: .catalogo)
    /// print(json)
    /// ```
    public func requestJSON(
        endpoint: Endpoint,
        body: (any Encodable)? = nil,
        requestId: String = UUID().uuidString
    ) async throws -> String {
        let crudo = try await requestCrudo(endpoint: endpoint, body: body, requestId: requestId)
        return crudo.jsonPretty ?? crudo.utf8String ?? "<respuesta no legible>"
    }

    // MARK: - Cancelación

    /// Cancela una petición activa por su `requestId`.
    ///
    /// ```swift
    /// let rid = UUID().uuidString
    /// let task = Task {
    ///     try await cliente.request(endpoint: .catalogo, tipo: Catalogo.self, requestId: rid)
    /// }
    /// // Más tarde...
    /// cliente.cancelar(requestId: rid)
    /// ```
    public func cancelar(requestId: String) {
        tareasActivas.withLock { tareas in
            tareas[requestId]?.cancel()
            tareas.removeValue(forKey: requestId)
        }
        log(.info, "🚫 Petición cancelada rid=\(requestId)")
    }

    /// Cancela todas las peticiones activas.
    public func cancelarTodo() {
        tareasActivas.withLock { tareas in
            tareas.values.forEach { $0.cancel() }
            tareas.removeAll()
        }
        log(.info, "🚫 Todas las peticiones canceladas")
    }

    // MARK: - Cache HTTP (ETags / URLCache)

    /// Configura la cache HTTP del cliente.
    ///
    /// Usa `.reloadIgnoringLocalCacheData` para deshabilitar cache,
    /// o `.returnCacheDataElseLoad` para modo offline.
    ///
    /// El servidor controla la validez mediante cabeceras `ETag` o `Cache-Control`.
    /// Con ETags, si el recurso no cambió el servidor responde `304 Not Modified`
    /// y `URLSession` devuelve los datos cacheados automáticamente.
    ///
    /// ```swift
    /// // Habilitar cache con 50 MB en memoria y 200 MB en disco
    /// cliente.configurarCache(memoriaBytes: 50_000_000, discoBytes: 200_000_000)
    /// ```
    public func configurarCache(memoriaBytes: Int = 20_000_000, discoBytes: Int = 100_000_000) {
        URLCache.shared = URLCache(
            memoryCapacity: memoriaBytes,
            diskCapacity: discoBytes,
            diskPath: "RedProfesionalCache"
        )
        log(.info, "💾 Cache HTTP configurada: \(memoriaBytes / 1_000_000) MB mem / \(discoBytes / 1_000_000) MB disco")
    }

    /// Limpia toda la cache HTTP.
    public func limpiarCache() {
        URLCache.shared.removeAllCachedResponses()
        log(.info, "🗑️ Cache HTTP limpiada")
    }

    // MARK: - Construcción de URLRequest

    private func construirRequest(
        endpoint: Endpoint,
        body: (any Encodable)?,
        requestId: String
    ) throws -> URLRequest {

        let pathNormalizado = endpoint.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))

        guard var comps = URLComponents(
            url: baseURL.appendingPathComponent(pathNormalizado),
            resolvingAgainstBaseURL: false
        ) else { throw ErrorRed.urlInvalida }

        if !endpoint.query.isEmpty {
            comps.queryItems = endpoint.query.map { URLQueryItem(name: $0.key, value: $0.value) }
        }

        guard let url = comps.url else { throw ErrorRed.urlInvalida }

        var req = URLRequest(url: url)
        req.httpMethod = endpoint.metodo.rawValue
        req.timeoutInterval = endpoint.timeout ?? timeoutPorDefecto
        req.cachePolicy = endpoint.politicaCache ?? .useProtocolCachePolicy

        // Headers base
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.setValue(requestId,          forHTTPHeaderField: "X-Request-ID")

        // Auth
        if let t = token {
            req.setValue("Bearer \(t)", forHTTPHeaderField: "Authorization")
        }

        // Headers por endpoint (pueden sobreescribir los base)
        for (k, v) in endpoint.headers {
            req.setValue(v, forHTTPHeaderField: k)
        }

        // Body JSON
        if let body {
            req.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
            do {
                req.httpBody = try jsonEncoder.encode(AnyEncodable(body))
            } catch {
                throw ErrorRed.encoding(detalle: error.localizedDescription)
            }
        }

        return req
    }

    // MARK: - Helpers privados

    private func validarHTTP(response: URLResponse, data: Data) throws -> HTTPURLResponse {
        guard let http = response as? HTTPURLResponse else {
            throw ErrorRed.sinRespuestaHTTP
        }
        guard (200...299).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8)
            throw ErrorRed.http(codigo: http.statusCode, body: body)
        }
        return http
    }

    private func decodificar<T: Decodable>(_ tipo: T.Type, data: Data) throws -> T {
        do {
            return try jsonDecoder.decode(T.self, from: data)
        } catch {
            throw ErrorRed.decoding(detalle: error.localizedDescription)
        }
    }

    private func log(_ nivel: EventoLogRed.Nivel, _ mensaje: String) {
        logger?.log(.init(nivel: nivel, mensaje: mensaje))
    }

    // MARK: - Tipos auxiliares

    /// Para endpoints que responden 204 o cuerpo vacío.
    public struct RespuestaVacia: Decodable, Sendable {
        public init() {}
    }

    private struct AnyEncodable: Encodable {
        let value: any Encodable
        init(_ value: any Encodable) { self.value = value }
        func encode(to encoder: Encoder) throws { try value.encode(to: encoder) }
    }
}

// MARK: - Locked<T> — wrapper thread-safe para propiedades mutables

/// Wrapper que protege un valor con un `NSLock` para acceso seguro desde múltiples hilos.
final class Locked<T>: @unchecked Sendable {
    private var _value: T
    private let lock = NSLock()

    init(_ value: T) { self._value = value }

    var value: T {
        lock.withLock { _value }
    }

    func setValue(_ newValue: T) {
        lock.withLock { _value = newValue }
    }

    @discardableResult
    func withLock<R>(_ body: (inout T) throws -> R) rethrows -> R {
        try lock.withLock { try body(&_value) }
    }
}

// MARK: - Extensiones de Data

public extension Data {

    /// JSON formateado y legible. `nil` si no es JSON válido.
    var jsonPretty: String? {
        guard let obj   = try? JSONSerialization.jsonObject(with: self),
              let pretty = try? JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted, .sortedKeys]),
              let str    = String(data: pretty, encoding: .utf8)
        else { return nil }
        return str
    }

    /// Texto UTF-8. `nil` si no es texto legible.
    var utf8String: String? {
        String(data: self, encoding: .utf8)
    }
}
