import Foundation

public struct ClienteHTTP: Sendable {

    public let baseURL: URL

    /// Token opcional (por ejemplo después de login)
    public var token: String? = nil

    /// Timeout por default si el endpoint no especifica uno.
    public var timeoutPorDefecto: TimeInterval = 15

    /// Política de reintentos (para estabilidad).
    public var politicaReintentos: PoliticaReintentos = .init()

    /// Logger opcional (puedes poner LoggerNulo en producción).
    public var logger: LoggerRed? = LoggerConsola()

    /// Encoder/Decoder configurables (PRO).
    /// Ej: jsonDecoder.keyDecodingStrategy = .convertFromSnakeCase
    public var jsonDecoder: JSONDecoder = {
        let d = JSONDecoder()
        return d
    }()

    public var jsonEncoder: JSONEncoder = {
        let e = JSONEncoder()
        return e
    }()

    private let session: URLSession

    public init(baseURL: URL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }

    // MARK: - API principal (Decodable)
    public func request<T: Decodable>(
        endpoint: Endpoint,
        tipo: T.Type,
        body: (any Encodable)? = nil,
        requestId: String = UUID().uuidString
    ) async throws -> T {

        var intento = 0

        while true {
            do {
                let req = try construirRequest(endpoint: endpoint, body: body, requestId: requestId)

                logger?.log(.init(
                    nivel: .debug,
                    mensaje: "➡️ \(req.httpMethod ?? "") \(req.url?.absoluteString ?? "") rid=\(requestId)"
                ))

                let (data, response) = try await session.data(for: req)
                let http = try validarHTTP(response: response, data: data)

                // 204 / body vacío
                if http.statusCode == 204 || data.isEmpty {
                    if T.self == RespuestaVacia.self {
                        return RespuestaVacia() as! T
                    } else {
                        throw ErrorRed.decoding(detalle: "Respuesta vacía, pero se esperaba JSON para \(T.self)")
                    }
                }

                let decodificado = try decodificar(T.self, data: data)

                logger?.log(.init(
                    nivel: .info,
                    mensaje: "✅ \(req.httpMethod ?? "") \(http.url?.absoluteString ?? "") [\(http.statusCode)] rid=\(requestId)"
                ))

                return decodificado

            } catch {
                let e = ErrorRed.desde(error)

                logger?.log(.init(
                    nivel: .error,
                    mensaje: "❌ \(endpoint.metodo.rawValue) \(endpoint.path) rid=\(requestId)\n\(e.detalleDebug)"
                ))

                if intento < politicaReintentos.maxReintentos, politicaReintentos.debeReintentar(e) {
                    let espera = politicaReintentos.delay(paraIntento: intento)
                    intento += 1
                    try? await Task.sleep(nanoseconds: UInt64(espera * 1_000_000_000))
                    continue
                }

                throw e
            }
        }
    }

    // MARK: - API para endpoints sin respuesta (204 / vacío)
    public func requestSinRespuesta(
        endpoint: Endpoint,
        body: (any Encodable)? = nil,
        requestId: String = UUID().uuidString
    ) async throws {
        _ = try await request(endpoint: endpoint, tipo: RespuestaVacia.self, body: body, requestId: requestId)
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

        // Headers base
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.setValue(requestId, forHTTPHeaderField: "X-Request-ID")

        // Auth
        if let token {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        // Headers por endpoint
        for (k, v) in endpoint.headers {
            req.setValue(v, forHTTPHeaderField: k)
        }

        // Body JSON (si se manda)
        if let body {
            req.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
            do {
                // ✅ usa el encoder configurable
                req.httpBody = try jsonEncoder.encode(AnyEncodable(body))
            } catch {
                throw ErrorRed.encoding(detalle: error.localizedDescription)
            }
        }

        return req
    }

    // MARK: - Validar HTTP y mapear errores HTTP
    private func validarHTTP(response: URLResponse, data: Data) throws -> HTTPURLResponse {
        guard let http = response as? HTTPURLResponse else {
            throw ErrorRed.sinRespuestaHTTP
        }

        if (200...299).contains(http.statusCode) {
            return http
        }

        let body = String(data: data, encoding: .utf8)
        throw ErrorRed.http(codigo: http.statusCode, body: body)
    }

    // MARK: - Decoding
    private func decodificar<T: Decodable>(_ tipo: T.Type, data: Data) throws -> T {
        do {
            // ✅ usa el decoder configurable
            return try jsonDecoder.decode(T.self, from: data)
        } catch {
            throw ErrorRed.decoding(detalle: error.localizedDescription)
        }
    }

    // MARK: - Tipos auxiliares

    /// Para endpoints que responden 204 o cuerpo vacío.
    public struct RespuestaVacia: Decodable, Sendable {
        public init() {}
    }

    /// Wrapper para poder encodar `any Encodable`.
    private struct AnyEncodable: Encodable {
        let value: any Encodable
        init(_ value: any Encodable) { self.value = value }
        func encode(to encoder: Encoder) throws { try value.encode(to: encoder) }
    }
}
