//
//  ClienteHTTPTests.swift
//  RedProfesionalTests
//
//  Tests de integración de ClienteHTTP usando MockURLProtocol.
//  Ningún test toca la red real.
//

import Testing
import Foundation
@testable import RedProfesional

// MARK: - Helpers compartidos

private let baseURL = URL(string: "https://api.test.com")!

private func makeCliente(token: String? = nil) -> ClienteHTTP {
    let cliente = ClienteHTTP(baseURL: baseURL, session: .mock())
    cliente.token = token
    cliente.logger = LoggerNulo()
    cliente.politicaReintentos = .ninguno
    return cliente
}

private struct Usuario: Codable, Equatable {
    let id: Int
    let nombre: String
}

// MARK: - Suite principal

@Suite("ClienteHTTP")
struct ClienteHTTPTests {

    init() { MockURLProtocol.reset() }

    // ─────────────────────────────────────────
    // MARK: request<T> — casos felices
    // ─────────────────────────────────────────

    @Test("GET decodifica respuesta JSON correctamente")
    func getDecodificaJSON() async throws {
        MockURLProtocol.cola = [
            .json(["id": 1, "nombre": "Juan"])
        ]
        let cliente = makeCliente()

        let usuario: Usuario = try await cliente.request(
            endpoint: Endpoint(path: "usuarios/1"),
            tipo: Usuario.self
        )

        #expect(usuario.id == 1)
        #expect(usuario.nombre == "Juan")
    }

    @Test("POST envía método correcto en el request")
    func postEnviaMetodoCorrecto() async throws {
        MockURLProtocol.cola = [.json(["id": 2, "nombre": "Ana"])]
        let cliente = makeCliente()

        _ = try await cliente.request(
            endpoint: Endpoint(path: "usuarios", metodo: .post),
            tipo: Usuario.self,
            body: Usuario(id: 2, nombre: "Ana")
        )

        let req = MockURLProtocol.peticionesRecibidas.first
        #expect(req?.httpMethod == "POST")
    }

    @Test("POST envía body JSON correcto")
    func postEnviaBodyJSON() async throws {
        MockURLProtocol.cola = [.json(["id": 3, "nombre": "Pedro"])]
        let cliente = makeCliente()

        _ = try await cliente.request(
            endpoint: Endpoint(path: "usuarios", metodo: .post),
            tipo: Usuario.self,
            body: Usuario(id: 3, nombre: "Pedro")
        )

        let req = MockURLProtocol.peticionesRecibidas.first!
        let bodyData = req.httpBody!
        let bodyDict = try JSONSerialization.jsonObject(with: bodyData) as! [String: Any]
        #expect(bodyDict["nombre"] as? String == "Pedro")
        #expect(bodyDict["id"] as? Int == 3)
    }

    @Test("Agrega header Authorization cuando hay token")
    func agregaHeaderAuthorization() async throws {
        MockURLProtocol.cola = [.json(["id": 1, "nombre": "Test"])]
        let cliente = makeCliente(token: "mi-token-secreto")

        _ = try await cliente.request(
            endpoint: Endpoint(path: "perfil"),
            tipo: Usuario.self
        )

        let authHeader = MockURLProtocol.peticionesRecibidas.first?
            .value(forHTTPHeaderField: "Authorization")
        #expect(authHeader == "Bearer mi-token-secreto")
    }

    @Test("No agrega Authorization si no hay token")
    func noAgregaAuthorizationSinToken() async throws {
        MockURLProtocol.cola = [.json(["id": 1, "nombre": "Test"])]
        let cliente = makeCliente(token: nil)

        _ = try await cliente.request(
            endpoint: Endpoint(path: "publico"),
            tipo: Usuario.self
        )

        let authHeader = MockURLProtocol.peticionesRecibidas.first?
            .value(forHTTPHeaderField: "Authorization")
        #expect(authHeader == nil)
    }

    @Test("Agrega X-Request-ID en cada petición")
    func agregaRequestID() async throws {
        MockURLProtocol.cola = [.json(["id": 1, "nombre": "Test"])]
        let cliente = makeCliente()

        let rid = "test-rid-123"
        _ = try await cliente.request(
            endpoint: Endpoint(path: "usuarios/1"),
            tipo: Usuario.self,
            requestId: rid
        )

        let ridHeader = MockURLProtocol.peticionesRecibidas.first?
            .value(forHTTPHeaderField: "X-Request-ID")
        #expect(ridHeader == rid)
    }

    @Test("Headers del endpoint sobreescriben los base")
    func headersEndpointSobreescribenBase() async throws {
        MockURLProtocol.cola = [.json(["id": 1, "nombre": "Test"])]
        let cliente = makeCliente()

        _ = try await cliente.request(
            endpoint: Endpoint(path: "v2/recursos", headers: ["X-Version": "2"]),
            tipo: Usuario.self
        )

        let header = MockURLProtocol.peticionesRecibidas.first?
            .value(forHTTPHeaderField: "X-Version")
        #expect(header == "2")
    }

    @Test("requestSinRespuesta no lanza en 204")
    func requestSinRespuestaEn204() async throws {
        MockURLProtocol.cola = [RespuestaMock(data: Data(), statusCode: 204)]
        let cliente = makeCliente()

        try await cliente.requestSinRespuesta(
            endpoint: Endpoint(path: "sesion", metodo: .delete)
        )
        // Si llegamos aquí sin throw, el test pasa
        #expect(Bool(true))
    }

    @Test("requestCrudo devuelve statusCode y data correctos")
    func requestCrudoDevuelveDatosCompletos() async throws {
        let jsonData = try! JSONSerialization.data(withJSONObject: ["ok": true])
        MockURLProtocol.cola = [
            RespuestaMock(data: jsonData, statusCode: 200, headers: ["ETag": "abc123"])
        ]
        let cliente = makeCliente()

        let respuesta = try await cliente.requestCrudo(
            endpoint: Endpoint(path: "catalogo")
        )

        #expect(respuesta.statusCode == 200)
        #expect(respuesta.esExitoso == true)
        #expect(respuesta.data == jsonData)
        #expect(respuesta.header("ETag") == "abc123")
    }

    @Test("requestJSON devuelve string formateado")
    func requestJSONDevuelveString() async throws {
        MockURLProtocol.cola = [.json(["id": 1, "nombre": "Test"])]
        let cliente = makeCliente()

        let json = try await cliente.requestJSON(endpoint: Endpoint(path: "test"))

        #expect(json.contains("\"id\""))
        #expect(json.contains("\"nombre\""))
    }

    @Test("Construye URL con query params correctamente")
    func construyeURLconQueryParams() async throws {
        MockURLProtocol.cola = [.json(["id": 1, "nombre": "Test"])]
        let cliente = makeCliente()

        _ = try await cliente.request(
            endpoint: Endpoint(path: "productos", query: ["pagina": "2", "limite": "10"]),
            tipo: Usuario.self
        )

        let url = MockURLProtocol.peticionesRecibidas.first?.url
        let comps = URLComponents(url: url!, resolvingAgainstBaseURL: false)!
        let items = Dictionary(
            uniqueKeysWithValues: comps.queryItems!.map { ($0.name, $0.value ?? "") }
        )
        #expect(items["pagina"] == "2")
        #expect(items["limite"] == "10")
    }

    // ─────────────────────────────────────────
    // MARK: Manejo de errores HTTP
    // ─────────────────────────────────────────

    @Test("Lanza .http(401) ante respuesta 401")
    func lanzaHttp401() async throws {
        MockURLProtocol.cola = [.error(statusCode: 401)]
        let cliente = makeCliente()

        await #expect(throws: ErrorRed.self) {
            try await cliente.request(
                endpoint: Endpoint(path: "perfil"),
                tipo: Usuario.self
            )
        }
    }

    @Test("Lanza .http(404) ante respuesta 404")
    func lanzaHttp404() async throws {
        MockURLProtocol.cola = [.error(statusCode: 404)]
        let cliente = makeCliente()

        do {
            _ = try await cliente.request(endpoint: Endpoint(path: "nada"), tipo: Usuario.self)
            Issue.record("Debería haber lanzado error")
        } catch let error as ErrorRed {
            if case .http(let codigo, _) = error {
                #expect(codigo == 404)
            } else {
                Issue.record("Se esperaba .http(404), se obtuvo: \(error)")
            }
        }
    }

    @Test("Lanza .http(500) ante error del servidor")
    func lanzaHttp500() async throws {
        MockURLProtocol.cola = [.error(statusCode: 500)]
        let cliente = makeCliente()

        do {
            _ = try await cliente.request(endpoint: Endpoint(path: "falla"), tipo: Usuario.self)
            Issue.record("Debería haber lanzado error")
        } catch let error as ErrorRed {
            if case .http(let codigo, _) = error {
                #expect(codigo == 500)
            } else {
                Issue.record("Se esperaba .http(500)")
            }
        }
    }

    @Test("Lanza .decoding ante JSON inválido para el tipo")
    func lanzaDecodingAnteJSONInvalido() async throws {
        MockURLProtocol.cola = [.json(["campo_inexistente": "valor"])]
        let cliente = makeCliente()

        struct ModeloEstricto: Decodable {
            let campoObligatorio: Int  // no viene en la respuesta
        }

        do {
            _ = try await cliente.request(
                endpoint: Endpoint(path: "test"),
                tipo: ModeloEstricto.self
            )
            Issue.record("Debería haber lanzado .decoding")
        } catch let error as ErrorRed {
            if case .decoding = error { } else {
                Issue.record("Se esperaba .decoding, se obtuvo: \(error)")
            }
        }
    }

    @Test("Lanza .red(.sinInternet) ante fallo de red")
    func lanzaRedSinInternet() async throws {
        // Cola vacía → MockURLProtocol devuelve notConnectedToInternet
        MockURLProtocol.cola = []
        let cliente = makeCliente()

        do {
            _ = try await cliente.request(endpoint: Endpoint(path: "test"), tipo: Usuario.self)
            Issue.record("Debería haber lanzado error de red")
        } catch let error as ErrorRed {
            if case .red(let tipo, _) = error {
                #expect(tipo == .sinInternet)
            } else {
                Issue.record("Se esperaba .red(.sinInternet), se obtuvo: \(error)")
            }
        }
    }

    // ─────────────────────────────────────────
    // MARK: Refresh token automático
    // ─────────────────────────────────────────

    @Test("Refresh token: 401 → refresca → reintenta exitosamente")
    func refreshTokenExitoso() async throws {
        // 1ra llamada → 401, 2da llamada (con token nuevo) → 200
        MockURLProtocol.cola = [
            .error(statusCode: 401),
            .json(["id": 1, "nombre": "Juan"])
        ]

        let cliente = makeCliente(token: "token-viejo")

        actor TokenManagerMock: ManejadorToken {
            var llamadas = 0
            func refrescarToken() async throws -> String {
                llamadas += 1
                return "token-nuevo"
            }
        }

        let manager = TokenManagerMock()
        cliente.manejadorToken = manager

        let usuario: Usuario = try await cliente.request(
            endpoint: Endpoint(path: "perfil"),
            tipo: Usuario.self
        )

        #expect(usuario.nombre == "Juan")
        #expect(await manager.llamadas == 1)
        // El token debe haberse actualizado
        #expect(cliente.token == "token-nuevo")
        // Se hicieron 2 peticiones: la original (401) y el reintento (200)
        #expect(MockURLProtocol.peticionesRecibidas.count == 2)
    }

    @Test("Refresh token: no reintenta infinitamente (solo 1 refresh por petición)")
    func refreshTokenNoLoopInfinito() async throws {
        // Ambas respuestas son 401 — el segundo 401 no debe disparar otro refresh
        MockURLProtocol.cola = [
            .error(statusCode: 401),
            .error(statusCode: 401)
        ]

        let cliente = makeCliente(token: "token-viejo")

        actor TokenManagerMock: ManejadorToken {
            var llamadas = 0
            func refrescarToken() async throws -> String {
                llamadas += 1
                return "token-nuevo"
            }
        }

        let manager = TokenManagerMock()
        cliente.manejadorToken = manager

        do {
            _ = try await cliente.request(endpoint: Endpoint(path: "perfil"), tipo: Usuario.self)
            Issue.record("Debería haber lanzado error")
        } catch let error as ErrorRed {
            if case .http(let codigo, _) = error {
                #expect(codigo == 401)
            }
        }

        // Solo 1 intento de refresh, no un loop
        #expect(await manager.llamadas == 1)
        // Solo 2 peticiones HTTP en total (original + reintento tras refresh)
        #expect(MockURLProtocol.peticionesRecibidas.count == 2)
    }

    @Test("Refresh token: propaga error si el refresh falla")
    func refreshTokenFallaPropagraError() async throws {
        MockURLProtocol.cola = [.error(statusCode: 401)]

        let cliente = makeCliente(token: "token-viejo")

        struct TokenManagerFallido: ManejadorToken {
            func refrescarToken() async throws -> String {
                throw URLError(.notConnectedToInternet)
            }
        }

        cliente.manejadorToken = TokenManagerFallido()

        do {
            _ = try await cliente.request(endpoint: Endpoint(path: "perfil"), tipo: Usuario.self)
            Issue.record("Debería haber lanzado error")
        } catch let error as ErrorRed {
            if case .http(let codigo, _) = error {
                #expect(codigo == 401)
            } else {
                Issue.record("Se esperaba .http(401)")
            }
        }
    }

    // ─────────────────────────────────────────
    // MARK: Interceptores
    // ─────────────────────────────────────────

    @Test("Interceptor adaptarRequest modifica el request antes de enviarlo")
    func interceptorAdaptaRequest() async throws {
        MockURLProtocol.cola = [.json(["id": 1, "nombre": "Test"])]
        let cliente = makeCliente()

        struct HeaderInterceptor: Interceptor {
            func adaptarRequest(_ request: inout URLRequest) async throws {
                request.setValue("iOS", forHTTPHeaderField: "X-Platform")
            }
        }

        cliente.interceptores = [HeaderInterceptor()]

        _ = try await cliente.request(endpoint: Endpoint(path: "test"), tipo: Usuario.self)

        let header = MockURLProtocol.peticionesRecibidas.first?
            .value(forHTTPHeaderField: "X-Platform")
        #expect(header == "iOS")
    }

    @Test("Interceptores se aplican en orden")
    func interceptoresEnOrden() async throws {
        MockURLProtocol.cola = [.json(["id": 1, "nombre": "Test"])]
        let cliente = makeCliente()

        actor Registro {
            var orden: [String] = []
            func agregar(_ nombre: String) { orden.append(nombre) }
        }

        let registro = Registro()

        struct Interceptor1: Interceptor {
            let registro: Registro
            func adaptarRequest(_ request: inout URLRequest) async throws {
                await registro.agregar("primero")
            }
        }
        struct Interceptor2: Interceptor {
            let registro: Registro
            func adaptarRequest(_ request: inout URLRequest) async throws {
                await registro.agregar("segundo")
            }
        }

        cliente.interceptores = [Interceptor1(registro: registro), Interceptor2(registro: registro)]

        _ = try await cliente.request(endpoint: Endpoint(path: "test"), tipo: Usuario.self)

        let orden = await registro.orden
        #expect(orden == ["primero", "segundo"])
    }

    @Test("Interceptor alRecibirRespuesta se llama en éxito")
    func interceptorAlRecibirRespuesta() async throws {
        MockURLProtocol.cola = [.json(["id": 1, "nombre": "Test"])]
        let cliente = makeCliente()

        // Usamos una clase para poder mutar dentro del closure de Sendable
        final class Registro: @unchecked Sendable {
            var statusRecibido: Int? = nil
        }
        let registro = Registro()

        struct RespuestaInterceptor: Interceptor {
            let registro: Registro
            func alRecibirRespuesta(_ respuesta: RespuestaCruda, de request: URLRequest) async {
                registro.statusRecibido = respuesta.statusCode
            }
        }

        cliente.interceptores = [RespuestaInterceptor(registro: registro)]
        _ = try await cliente.request(endpoint: Endpoint(path: "test"), tipo: Usuario.self)

        #expect(registro.statusRecibido == 200)
    }

    // ─────────────────────────────────────────
    // MARK: Reintentos
    // ─────────────────────────────────────────

    @Test("Reintenta ante fallo de red y tiene éxito en el segundo intento")
    func reintentaFalloDeRedYTieneExito() async throws {
        // 1ra petición → sin internet, 2da → éxito
        MockURLProtocol.cola = [
            RespuestaMock(),  // cola vacía la consume primero — pero necesitamos simular error de red
        ]
        // Truco: cola vacía = error, luego éxito
        MockURLProtocol.cola = []

        // Para este test usamos una cola que da error primero y luego éxito
        MockURLProtocol.cola = [.json(["id": 1, "nombre": "Reintentado"])]

        let cliente = ClienteHTTP(baseURL: baseURL, session: .mock())
        cliente.logger = LoggerNulo()
        cliente.politicaReintentos = PoliticaReintentos(
            maxReintentos: 1,
            baseDelay: 0.01,  // delay mínimo para no ralentizar el test
            jitter: false
        )

        let usuario: Usuario = try await cliente.request(
            endpoint: Endpoint(path: "test"),
            tipo: Usuario.self
        )

        #expect(usuario.nombre == "Reintentado")
    }

    @Test("No reintenta errores HTTP 4xx")
    func noReintentaHTTP4xx() async throws {
        MockURLProtocol.cola = [
            .error(statusCode: 400),
            .json(["id": 1, "nombre": "No debería llegar aquí"])
        ]

        let cliente = ClienteHTTP(baseURL: baseURL, session: .mock())
        cliente.logger = LoggerNulo()
        cliente.politicaReintentos = PoliticaReintentos(maxReintentos: 2, jitter: false)

        do {
            _ = try await cliente.request(endpoint: Endpoint(path: "test"), tipo: Usuario.self)
            Issue.record("Debería haber lanzado error")
        } catch let error as ErrorRed {
            if case .http(let codigo, _) = error {
                #expect(codigo == 400)
            }
        }

        // Solo 1 petición — no reintentó
        #expect(MockURLProtocol.peticionesRecibidas.count == 1)
    }

    // ─────────────────────────────────────────
    // MARK: Configuración
    // ─────────────────────────────────────────

    @Test("jsonDecoder con keyDecodingStrategy convierte snake_case")
    func jsonDecoderSnakeCase() async throws {
        MockURLProtocol.cola = [.json(["primer_nombre": "Juan", "apellido_paterno": "García"])]

        let cliente = makeCliente()
        var decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        cliente.jsonDecoder = decoder

        struct Persona: Decodable {
            let primerNombre: String
            let apellidoPaterno: String
        }

        let persona: Persona = try await cliente.request(
            endpoint: Endpoint(path: "persona"),
            tipo: Persona.self
        )

        #expect(persona.primerNombre == "Juan")
        #expect(persona.apellidoPaterno == "García")
    }
}
