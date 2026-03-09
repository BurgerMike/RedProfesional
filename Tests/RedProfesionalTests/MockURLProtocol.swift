//
//  MockURLProtocol.swift
//  RedProfesionalTests
//
//  Intercepta URLSession en tests para simular respuestas HTTP
//  sin tocar la red real.
//

import Foundation

/// Respuesta simulada que `MockURLProtocol` devuelve al cliente.
struct RespuestaMock {
    let data: Data
    let statusCode: Int
    let headers: [String: String]

    init(data: Data = Data(), statusCode: Int = 200, headers: [String: String] = [:]) {
        self.data = data
        self.statusCode = statusCode
        self.headers = headers
    }

    /// Construye una respuesta JSON a partir de un diccionario.
    static func json(_ dict: [String: Any], statusCode: Int = 200) -> RespuestaMock {
        let data = try! JSONSerialization.data(withJSONObject: dict)
        return RespuestaMock(
            data: data,
            statusCode: statusCode,
            headers: ["Content-Type": "application/json"]
        )
    }

    /// Respuesta de error HTTP sin body.
    static func error(statusCode: Int) -> RespuestaMock {
        RespuestaMock(data: Data(), statusCode: statusCode)
    }
}

/// `URLProtocol` personalizado que intercepta todas las peticiones de una
/// `URLSession` de test y devuelve la respuesta configurada en `cola`.
final class MockURLProtocol: URLProtocol, @unchecked Sendable {

    /// Cola de respuestas. Cada petición consume una entrada en orden FIFO.
    /// Si la cola está vacía, devuelve un error de red.
    static var cola: [RespuestaMock] = []

    /// Registra cuántas peticiones fueron interceptadas y sus URLs.
    static var peticionesRecibidas: [URLRequest] = []

    /// Resetea el estado entre tests.
    static func reset() {
        cola = []
        peticionesRecibidas = []
    }

    // MARK: - URLProtocol

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        MockURLProtocol.peticionesRecibidas.append(request)

        guard !MockURLProtocol.cola.isEmpty else {
            client?.urlProtocol(self, didFailWithError: URLError(.notConnectedToInternet))
            return
        }

        let mock = MockURLProtocol.cola.removeFirst()

        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: mock.statusCode,
            httpVersion: "HTTP/1.1",
            headerFields: mock.headers
        )!

        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: mock.data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

// MARK: - Helper para crear URLSession con el mock

extension URLSession {
    /// Crea una `URLSession` que intercepta todas las peticiones con `MockURLProtocol`.
    static func mock() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        return URLSession(configuration: config)
    }
}
