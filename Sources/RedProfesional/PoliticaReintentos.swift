//
//  PoliticaReintentos.swift
//  RedProfesional
//

import Foundation

/// Política de reintentos ante fallos transitorios de red.
///
/// Usa backoff exponencial con jitter para evitar "thundering herd"
/// cuando múltiples clientes reintentan al mismo tiempo.
///
/// ```swift
/// // Por defecto: 1 reintento, delay base 0.6s
/// cliente.politicaReintentos = .default
///
/// // Agresivo: 3 reintentos, delay base 1s
/// cliente.politicaReintentos = PoliticaReintentos(maxReintentos: 3, baseDelay: 1.0)
///
/// // También reintentar en 503 Service Unavailable
/// cliente.politicaReintentos = PoliticaReintentos(
///     maxReintentos: 3,
///     codigosHTTPReintentables: [503, 429]
/// )
/// ```
public struct PoliticaReintentos: Sendable {

    /// Número máximo de reintentos (no incluye el intento inicial).
    public var maxReintentos: Int

    /// Delay base en segundos. El delay real es `baseDelay * 2^intento ± jitter`.
    public var baseDelay: TimeInterval

    /// Delay máximo aplicable, independientemente del backoff calculado.
    public var maxDelay: TimeInterval

    /// Si `true`, añade ruido aleatorio al delay para evitar thundering herd.
    public var jitter: Bool

    /// Códigos HTTP que también se reintentarán (ej. 503, 429).
    /// Por defecto vacío: solo errores de red se reintentan.
    public var codigosHTTPReintentables: Set<Int>

    public init(
        maxReintentos: Int = 1,
        baseDelay: TimeInterval = 0.6,
        maxDelay: TimeInterval = 30.0,
        jitter: Bool = true,
        codigosHTTPReintentables: Set<Int> = []
    ) {
        self.maxReintentos = maxReintentos
        self.baseDelay = baseDelay
        self.maxDelay = maxDelay
        self.jitter = jitter
        self.codigosHTTPReintentables = codigosHTTPReintentables
    }

    /// Configuración por defecto: 1 reintento, backoff con jitter.
    public static let `default` = PoliticaReintentos()

    /// Sin reintentos.
    public static let ninguno = PoliticaReintentos(maxReintentos: 0)

    // MARK: - Lógica

    /// Decide si este error amerita reintento.
    public func debeReintentar(_ error: ErrorRed) -> Bool {
        switch error {
        case .red(tipo: .timeout, _),
             .red(tipo: .conexionPerdida, _),
             .red(tipo: .dns, _),
             .red(tipo: .sinInternet, _):
            return true
        case .http(let codigo, _):
            return codigosHTTPReintentables.contains(codigo)
        default:
            return false
        }
    }

    /// Calcula el delay para el intento dado con backoff exponencial y jitter opcional.
    ///
    /// Fórmula: `min(baseDelay * 2^intento, maxDelay) ± jitter`
    public func delay(paraIntento intento: Int) -> TimeInterval {
        let exponencial = baseDelay * pow(2.0, Double(intento))
        let acotado = min(exponencial, maxDelay)
        guard jitter else { return acotado }
        // Jitter: ±25% del delay calculado
        let variacion = acotado * 0.25
        let ruido = Double.random(in: -variacion...variacion)
        return max(0, acotado + ruido)
    }
}

