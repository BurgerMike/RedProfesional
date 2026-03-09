//
//  LoggerRed.swift
//  RedProfesional
//

import Foundation
import OSLog

/// Protocolo de logging para eventos de red.
///
/// Implementa este protocolo para integrar tu propio sistema de métricas o logging:
/// ```swift
/// struct MiLogger: LoggerRed {
///     func log(_ evento: EventoLogRed) {
///         MiSistemaAnalytics.track(evento.mensaje, nivel: evento.nivel.rawValue)
///     }
/// }
/// cliente.logger = MiLogger()
/// ```
public protocol LoggerRed: Sendable {
    func log(_ evento: EventoLogRed)
}

/// Evento de log generado por el cliente HTTP.
public struct EventoLogRed: Sendable {

    /// Nivel de severidad. Orden ascendente: `debug < info < warning < error`.
    public enum Nivel: String, Sendable, Comparable, CaseIterable {
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

// MARK: - LoggerConsola

/// Logger que escribe en el sistema de logging unificado de Apple (`os.Logger`).
///
/// Los eventos aparecen en **Console.app** e **Instruments**, con soporte para
/// filtros por subsistema y categoría. Solo imprime eventos iguales o superiores
/// a `nivelMinimo`.
///
/// - `nivelMinimo: .debug` → todo (desarrollo).
/// - `nivelMinimo: .error` → solo errores (producción).
///
/// ```swift
/// // Desarrollo
/// cliente.logger = LoggerConsola(nivelMinimo: .debug)
///
/// // Producción
/// cliente.logger = LoggerConsola(nivelMinimo: .error)
///
/// // Subsistema y categoría personalizados
/// cliente.logger = LoggerConsola(subsistema: "com.miapp", categoria: "API")
/// ```
public struct LoggerConsola: LoggerRed {

    public var nivelMinimo: EventoLogRed.Nivel
    private let osLogger: Logger

    public init(
        nivelMinimo: EventoLogRed.Nivel = .debug,
        subsistema: String = Bundle.main.bundleIdentifier ?? "RedProfesional",
        categoria: String = "RedProfesional"
    ) {
        self.nivelMinimo = nivelMinimo
        self.osLogger = Logger(subsystem: subsistema, category: categoria)
    }

    public func log(_ evento: EventoLogRed) {
        guard evento.nivel >= nivelMinimo else { return }
        switch evento.nivel {
        case .debug:   osLogger.debug("\(evento.mensaje, privacy: .public)")
        case .info:    osLogger.info("\(evento.mensaje, privacy: .public)")
        case .warning: osLogger.warning("\(evento.mensaje, privacy: .public)")
        case .error:   osLogger.error("\(evento.mensaje, privacy: .public)")
        }
    }
}

// MARK: - LoggerNulo

/// Logger nulo (no emite nada). Ideal para producción cuando no se necesita logging.
public struct LoggerNulo: LoggerRed {
    public init() {}
    public func log(_ evento: EventoLogRed) {}
}

// MARK: - LoggerMultiplex

/// Logger que reenvía cada evento a múltiples loggers simultáneamente.
///
/// ```swift
/// cliente.logger = LoggerMultiplex([
///     LoggerConsola(nivelMinimo: .debug),
///     MiLoggerRemoto()
/// ])
/// ```
public struct LoggerMultiplex: LoggerRed {
    private let loggers: [any LoggerRed]

    public init(_ loggers: [any LoggerRed]) {
        self.loggers = loggers
    }

    public func log(_ evento: EventoLogRed) {
        loggers.forEach { $0.log(evento) }
    }
}

