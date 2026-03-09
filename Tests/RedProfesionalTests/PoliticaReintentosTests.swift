//
//  PoliticaReintentosTests.swift
//  RedProfesionalTests
//

import Testing
import Foundation
@testable import RedProfesional

@Suite("PoliticaReintentos")
struct PoliticaReintentosTests {

    // MARK: - debeReintentar

    @Test("Reintenta en sinInternet")
    func reintentaSinInternet() {
        let politica = PoliticaReintentos()
        #expect(politica.debeReintentar(.red(tipo: .sinInternet)) == true)
    }

    @Test("Reintenta en timeout")
    func reintentaTimeout() {
        let politica = PoliticaReintentos()
        #expect(politica.debeReintentar(.red(tipo: .timeout)) == true)
    }

    @Test("Reintenta en conexionPerdida")
    func reintentaConexionPerdida() {
        let politica = PoliticaReintentos()
        #expect(politica.debeReintentar(.red(tipo: .conexionPerdida)) == true)
    }

    @Test("No reintenta en HTTP 400 por defecto")
    func noReintentaHTTP400() {
        let politica = PoliticaReintentos()
        #expect(politica.debeReintentar(.http(codigo: 400)) == false)
    }

    @Test("No reintenta en HTTP 500 por defecto")
    func noReintentaHTTP500() {
        let politica = PoliticaReintentos()
        #expect(politica.debeReintentar(.http(codigo: 500)) == false)
    }

    @Test("Reintenta en 503 si está configurado")
    func reintenta503Configurado() {
        let politica = PoliticaReintentos(codigosHTTPReintentables: [503])
        #expect(politica.debeReintentar(.http(codigo: 503)) == true)
    }

    @Test("No reintenta en ssl")
    func noReintentaSSL() {
        let politica = PoliticaReintentos()
        #expect(politica.debeReintentar(.red(tipo: .ssl)) == false)
    }

    // MARK: - delay

    @Test("Delay crece exponencialmente sin jitter")
    func delaySinJitter() {
        let politica = PoliticaReintentos(baseDelay: 1.0, jitter: false)
        #expect(politica.delay(paraIntento: 0) == 1.0)
        #expect(politica.delay(paraIntento: 1) == 2.0)
        #expect(politica.delay(paraIntento: 2) == 4.0)
    }

    @Test("Delay no supera maxDelay")
    func delayAcotado() {
        let politica = PoliticaReintentos(baseDelay: 10.0, maxDelay: 15.0, jitter: false)
        let d = politica.delay(paraIntento: 5) // 10 * 32 = 320, debe acotarse
        #expect(d <= 15.0)
    }

    @Test("Delay con jitter es positivo")
    func delayConJitterPositivo() {
        let politica = PoliticaReintentos(baseDelay: 1.0, jitter: true)
        for intento in 0..<5 {
            #expect(politica.delay(paraIntento: intento) >= 0)
        }
    }

    // MARK: - Presets

    @Test("PoliticaReintentos.ninguno no reintenta")
    func presetNinguno() {
        #expect(PoliticaReintentos.ninguno.maxReintentos == 0)
    }

    @Test("PoliticaReintentos.default tiene maxReintentos >= 1")
    func presetDefault() {
        #expect(PoliticaReintentos.default.maxReintentos >= 1)
    }
}
