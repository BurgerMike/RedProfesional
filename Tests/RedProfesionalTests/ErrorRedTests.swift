//
//  ErrorRedTests.swift
//  RedProfesionalTests
//

import Testing
import Foundation
@testable import RedProfesional

@Suite("ErrorRed")
struct ErrorRedTests {

    // MARK: - desde(_:)

    @Test("Mapea URLError.notConnectedToInternet → .red(.sinInternet)")
    func mapeaSinInternet() {
        let urlError = URLError(.notConnectedToInternet)
        let error = ErrorRed.desde(urlError)
        #expect(error == .red(tipo: .sinInternet))
    }

    @Test("Mapea URLError.timedOut → .red(.timeout)")
    func mapeaTimeout() {
        let error = ErrorRed.desde(URLError(.timedOut))
        #expect(error == .red(tipo: .timeout))
    }

    @Test("Mapea URLError.cancelled → .red(.cancelado)")
    func mapeaCancelado() {
        let error = ErrorRed.desde(URLError(.cancelled))
        #expect(error == .red(tipo: .cancelado))
    }

    @Test("Mapea URLError.dnsLookupFailed → .red(.dns)")
    func mapeaDNS() {
        let error = ErrorRed.desde(URLError(.dnsLookupFailed))
        if case .red(let tipo, _) = error {
            #expect(tipo == .dns)
        } else {
            Issue.record("Se esperaba .red(.dns)")
        }
    }

    @Test("Mapea URLError.networkConnectionLost → .red(.conexionPerdida)")
    func mapeaConexionPerdida() {
        let error = ErrorRed.desde(URLError(.networkConnectionLost))
        if case .red(let tipo, _) = error {
            #expect(tipo == .conexionPerdida)
        } else {
            Issue.record("Se esperaba .red(.conexionPerdida)")
        }
    }

    @Test("Pasa ErrorRed sin transformar")
    func pasaErrorRedDirecto() {
        let original = ErrorRed.urlInvalida
        let resultado = ErrorRed.desde(original)
        #expect(resultado == original)
    }

    @Test("Error desconocido → .desconocido")
    func mapeaDesconocido() {
        struct OtroError: Error {}
        let error = ErrorRed.desde(OtroError())
        if case .desconocido = error { } else {
            Issue.record("Se esperaba .desconocido")
        }
    }

    // MARK: - mensajeUsuario

    @Test("mensajeUsuario para .urlInvalida")
    func mensajeURLInvalida() {
        #expect(!ErrorRed.urlInvalida.mensajeUsuario.isEmpty)
    }

    @Test("mensajeUsuario para HTTP 401")
    func mensajeHttp401() {
        let msg = ErrorRed.http(codigo: 401).mensajeUsuario
        #expect(msg.contains("Sesión") || msg.contains("sesión"))
    }

    @Test("mensajeUsuario para HTTP 404")
    func mensajeHttp404() {
        let msg = ErrorRed.http(codigo: 404).mensajeUsuario
        #expect(msg.contains("encontró") || msg.contains("recurso"))
    }

    // MARK: - detalleDebug

    @Test("detalleDebug incluye código HTTP")
    func detalleDebugHTTP() {
        let detalle = ErrorRed.http(codigo: 500, body: "internal").detalleDebug
        #expect(detalle.contains("500"))
    }
}
