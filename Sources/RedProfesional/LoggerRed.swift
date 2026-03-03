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
    public enum Nivel: Sendable {
        case debug
        case info
        case warning
        case error
    }

    public var nivel: Nivel
    public var mensaje: String

    public init(nivel: Nivel, mensaje: String) {
        self.nivel = nivel
        self.mensaje = mensaje
    }
}

/// Logger simple por defecto (print). Ideal para aprender.
public struct LoggerConsola: LoggerRed {
    public init() {}

    public func log(_ evento: EventoLogRed) {
        print("[RED][\(evento.nivel)] \(evento.mensaje)")
    }
}

/// Logger nulo (no imprime nada). Útil para producción si no quieres logs.
public struct LoggerNulo: LoggerRed {
    public init() {}

    public func log(_ evento: EventoLogRed) {
        // no-op
    }
}
