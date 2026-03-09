//
//  InterceptorTests.swift
//  RedProfesionalTests
//

import Testing
import Foundation
@testable import RedProfesional

@Suite("Interceptor")
struct InterceptorTests {

    // MARK: - Mock

    actor InterceptorMock: Interceptor {
        var requestsAdaptados: [URLRequest] = []
        var respuestasRecibidas: [RespuestaCruda] = []
        var erroresRecibidos: [ErrorRed] = []

        nonisolated func adaptarRequest(_ request: inout URLRequest) async throws {
            await registrarRequest(request)
            request.setValue("test-value", forHTTPHeaderField: "X-Test")
        }

        nonisolated func alRecibirRespuesta(_ respuesta: RespuestaCruda, de request: URLRequest) async {
            await registrarRespuesta(respuesta)
        }

        nonisolated func alFallar(_ error: ErrorRed, en request: URLRequest) async {
            await registrarError(error)
        }

        private func registrarRequest(_ req: URLRequest) { requestsAdaptados.append(req) }
        private func registrarRespuesta(_ r: RespuestaCruda) { respuestasRecibidas.append(r) }
        private func registrarError(_ e: ErrorRed) { erroresRecibidos.append(e) }
    }

    // MARK: - Tests de protocolo

    @Test("Interceptor con implementaciones vacías no lanza error")
    func implementacionesVaciasNoLanzan() async throws {
        struct InterceptorVacio: Interceptor {}
        let i = InterceptorVacio()
        var req = URLRequest(url: URL(string: "https://test.com")!)
        try await i.adaptarRequest(&req)
        let crudo = RespuestaCruda(data: Data(), statusCode: 200)
        await i.alRecibirRespuesta(crudo, de: req)
        await i.alFallar(.urlInvalida, en: req)
        // Si llegamos aquí, no lanzó
        #expect(Bool(true))
    }

    @Test("Endpoint incluye politicaCache nil por defecto")
    func politicaCacheNilPorDefecto() {
        let ep = Endpoint(path: "test")
        #expect(ep.politicaCache == nil)
    }

    @Test("Endpoint.sinCache tiene política reloadIgnoringLocalCacheData")
    func sinCacheTieneopoliticaCorrecta() {
        let ep = Endpoint.sinCache(path: "productos")
        #expect(ep.politicaCache == .reloadIgnoringLocalCacheData)
    }

    @Test("Endpoint.soloCache tiene política returnCacheDataDontLoad")
    func soloCacheTieneopoliticaCorrecta() {
        let ep = Endpoint.soloCache(path: "productos")
        #expect(ep.politicaCache == .returnCacheDataDontLoad)
    }
}
