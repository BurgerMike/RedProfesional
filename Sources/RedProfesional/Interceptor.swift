//
//  Interceptor.swift
//  RedProfesional
//

import Foundation

/// Protocolo para interceptar y modificar peticiones y respuestas HTTP.
///
/// Los interceptores se ejecutan en orden para cada petición.
/// Úsalos para añadir lógica transversal sin tocar el código de negocio.
///
/// ### Casos de uso típicos
/// - Añadir headers globales (versión de app, device ID, idioma)
/// - Firmar peticiones (HMAC, OAuth)
/// - Métricas y trazabilidad
/// - Modificar respuestas antes de que lleguen al caller
///
/// ### Ejemplo: header de versión de app
/// ```swift
/// struct VersionInterceptor: Interceptor {
///     func adaptarRequest(_ request: inout URLRequest) async throws {
///         let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
///         request.setValue(version, forHTTPHeaderField: "X-App-Version")
///         request.setValue(UIDevice.current.systemVersion, forHTTPHeaderField: "X-OS-Version")
///     }
/// }
/// ```
///
/// ### Ejemplo: métricas de tiempo de respuesta
/// ```swift
/// struct MetricasInterceptor: Interceptor {
///     func alRecibirRespuesta(_ respuesta: RespuestaCruda, de request: URLRequest) async {
///         // Enviar duración, statusCode, endpoint a tu sistema de métricas
///         MisMetricas.track(url: request.url, status: respuesta.statusCode)
///     }
/// }
/// ```
///
/// ### Registro
/// ```swift
/// cliente.interceptores = [
///     VersionInterceptor(),
///     MetricasInterceptor()
/// ]
/// ```
public protocol Interceptor: Sendable {

    /// Se llama justo antes de enviar la petición.
    /// Modifica `request` para añadir headers, firmar, etc.
    func adaptarRequest(_ request: inout URLRequest) async throws

    /// Se llama después de recibir una respuesta exitosa (2xx).
    func alRecibirRespuesta(_ respuesta: RespuestaCruda, de request: URLRequest) async

    /// Se llama cuando la petición falla con un error.
    func alFallar(_ error: ErrorRed, en request: URLRequest) async
}

// Implementaciones por defecto vacías — solo sobreescribe lo que necesitas
public extension Interceptor {
    func adaptarRequest(_ request: inout URLRequest) async throws {}
    func alRecibirRespuesta(_ respuesta: RespuestaCruda, de request: URLRequest) async {}
    func alFallar(_ error: ErrorRed, en request: URLRequest) async {}
}
