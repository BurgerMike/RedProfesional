//
//  PoliticaReintentos.swift
//  RedProfesional
//
//  Created by ChumBucketComputer on 03/03/26.
//

import Foundation

public struct PoliticaReintentos: Sendable {
    public var maxReintentos: Int
    public var baseDelay: TimeInterval

    public init(maxReintentos: Int = 1, baseDelay: TimeInterval = 0.6) {
        self.maxReintentos = maxReintentos
        self.baseDelay = baseDelay
    }

    /// Decide si este error amerita reintento.
    /// - Importante: NO reintentes errores de 4xx/5xx por default sin entender tu API.
    public func debeReintentar(_ error: ErrorRed) -> Bool {
        switch error {
        case .red(tipo: .timeout, _),
             .red(tipo: .conexionPerdida, _),
             .red(tipo: .dns, _),
             .red(tipo: .sinInternet, _):
            return true
        default:
            return false
        }
    }

    /// Backoff simple: base * 2^intento (intento empieza en 0)
    public func delay(paraIntento intento: Int) -> TimeInterval {
        baseDelay * pow(2, Double(intento))
    }
}
