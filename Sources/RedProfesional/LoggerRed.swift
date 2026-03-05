//
//  LoggerRed.swift
//  RedProfesional
//
//  Created by ChumBucketComputer on 03/03/26.
//

import Foundation

public protocol LoggerRed: Sendable {
    func log(_ evento: EventoLogRed)
}

public struct EventoLogRed: Sendable {
    /// Nivel de severidad del evento. El orden de comparación es: debug < info < warning < error.
    public enum Nivel: String, Sendable, Comparable {
        case debug   = "DEBUG  "
        case info    = "INFO   "
        case warning = "WARNING"
        case error   = "ERROR  "

        private var orden: Int {
            switch self {
            case .debug:   return 0
            case .info:    return 1
            case .warning: return 2
            case .error:   return 3
            }
        }

        public static func < (lhs: Nivel, rhs: Nivel) -> Bool {
            lhs.orden < rhs.orden
        }
    }

    public var nivel: Nivel
    public var mensaje: String
    /// Momento exacto en que se generó el evento.
    public var fecha: Date

    public init(nivel: Nivel, mensaje: String, fecha: Date = .now) {
        self.nivel = nivel
        self.mensaje = mensaje
        self.fecha = fecha
    }
}

/// Logger de consola. Imprime solo los eventos cuyo nivel es igual o superior a `nivelMinimo`.
///
/// - `nivelMinimo: .debug` → imprime todo (ideal en desarrollo).
/// - `nivelMinimo: .error` → imprime solo errores (ideal en producción).
public struct LoggerConsola: LoggerRed {
    /// Nivel mínimo para que el evento se imprima. Por defecto `.debug` (todo).
    public var nivelMinimo: EventoLogRed.Nivel

    private static let formato: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        return f
    }()

    public init(nivelMinimo: EventoLogRed.Nivel = .debug) {
        self.nivelMinimo = nivelMinimo
    }

    public func log(_ evento: EventoLogRed) {
        guard evento.nivel >= nivelMinimo else { return }
        let hora = Self.formato.string(from: evento.fecha)
        print("[RED] \(hora) [\(evento.nivel.rawValue)] \(evento.mensaje)")
    }
}

/// Logger nulo (no imprime nada). Útil para producción si no quieres logs.
public struct LoggerNulo: LoggerRed {
    public init() {}

    public func log(_ evento: EventoLogRed) {
        // no-op
    }
}
