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
    public enum Nivel: String, Sendable {
        case debug   = "DEBUG  "
        case info    = "INFO   "
        case warning = "WARNING"
        case error   = "ERROR  "
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

/// Logger simple por defecto (print). Ideal para desarrollo y depuración.
public struct LoggerConsola: LoggerRed {
    private static let formato: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        return f
    }()

    public init() {}

    public func log(_ evento: EventoLogRed) {
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
