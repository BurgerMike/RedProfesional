//
//  RespuestaCrudaTests.swift
//  RedProfesionalTests
//

import Testing
import Foundation
@testable import RedProfesional

@Suite("RespuestaCruda")
struct RespuestaCrudaTests {

    private func makeJSON(_ dict: [String: Any]) -> Data {
        try! JSONSerialization.data(withJSONObject: dict)
    }

    @Test("jsonPretty devuelve string formateado para JSON válido")
    func jsonPrettyValido() {
        let data = makeJSON(["nombre": "test", "id": 1])
        let respuesta = RespuestaCruda(data: data, statusCode: 200)
        #expect(respuesta.jsonPretty != nil)
        #expect(respuesta.esJSON == true)
    }

    @Test("jsonPretty devuelve nil para datos no-JSON")
    func jsonPrettyInvalido() {
        let data = Data("no es json".utf8)
        let respuesta = RespuestaCruda(data: data, statusCode: 200)
        #expect(respuesta.jsonPretty == nil)
        #expect(respuesta.esJSON == false)
    }

    @Test("utf8String decodifica texto plano")
    func utf8StringValido() {
        let texto = "hola mundo"
        let respuesta = RespuestaCruda(data: Data(texto.utf8), statusCode: 200)
        #expect(respuesta.utf8String == texto)
    }

    @Test("bytes refleja el tamaño del data")
    func bytesCorrectos() {
        let data = Data(repeating: 0, count: 42)
        let respuesta = RespuestaCruda(data: data, statusCode: 200)
        #expect(respuesta.bytes == 42)
    }

    @Test("esExitoso es true para 2xx")
    func esExitoso2xx() {
        for codigo in [200, 201, 204, 206, 299] {
            let r = RespuestaCruda(data: Data(), statusCode: codigo)
            #expect(r.esExitoso == true, "Falló para \(codigo)")
        }
    }

    @Test("esExitoso es false para 4xx y 5xx")
    func noExitoso4xx5xx() {
        for codigo in [400, 401, 403, 404, 500, 503] {
            let r = RespuestaCruda(data: Data(), statusCode: codigo)
            #expect(r.esExitoso == false, "Falló para \(codigo)")
        }
    }

    @Test("header() busca sin importar mayúsculas")
    func headerCaseInsensitive() {
        let r = RespuestaCruda(
            data: Data(),
            statusCode: 200,
            headers: ["Content-Type": "application/json", "X-Total-Count": "42"]
        )
        #expect(r.header("content-type") == "application/json")
        #expect(r.header("CONTENT-TYPE") == "application/json")
        #expect(r.header("x-total-count") == "42")
        #expect(r.header("X-Missing") == nil)
    }
}
