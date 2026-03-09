//
//  EndpointTests.swift
//  RedProfesionalTests
//

import Testing
import Foundation
@testable import RedProfesional

@Suite("Endpoint")
struct EndpointTests {

    @Test("Método por defecto es GET")
    func metodoPorDefectoGet() {
        #expect(Endpoint(path: "usuarios").metodo == .get)
    }

    @Test("Todos los métodos HTTP están disponibles")
    func metodosHTTP() {
        let casos: [Endpoint.Metodo] = [.get, .post, .put, .patch, .delete]
        let rawValues = casos.map(\.rawValue)
        #expect(rawValues.contains("GET"))
        #expect(rawValues.contains("POST"))
        #expect(rawValues.contains("PUT"))
        #expect(rawValues.contains("PATCH"))
        #expect(rawValues.contains("DELETE"))
    }

    @Test("Query, headers y timeout son vacíos/nil por defecto")
    func valoresPorDefecto() {
        let ep = Endpoint(path: "test")
        #expect(ep.query.isEmpty)
        #expect(ep.headers.isEmpty)
        #expect(ep.timeout == nil)
        #expect(ep.politicaCache == nil)
    }

    @Test("Inicialización completa conserva todos los valores")
    func inicializacionCompleta() {
        let ep = Endpoint(
            path: "auth/login",
            metodo: .post,
            query: ["v": "2"],
            headers: ["X-App": "iOS"],
            timeout: 10,
            politicaCache: .reloadIgnoringLocalCacheData
        )
        #expect(ep.path == "auth/login")
        #expect(ep.metodo == .post)
        #expect(ep.query["v"] == "2")
        #expect(ep.headers["X-App"] == "iOS")
        #expect(ep.timeout == 10)
        #expect(ep.politicaCache == .reloadIgnoringLocalCacheData)
    }

    @Test("Preset sinCache")
    func presetSinCache() {
        let ep = Endpoint.sinCache(path: "noticias", query: ["cat": "tech"])
        #expect(ep.path == "noticias")
        #expect(ep.query["cat"] == "tech")
        #expect(ep.politicaCache == .reloadIgnoringLocalCacheData)
    }

    @Test("Preset soloCache")
    func presetSoloCache() {
        let ep = Endpoint.soloCache(path: "config")
        #expect(ep.politicaCache == .returnCacheDataDontLoad)
    }
}

