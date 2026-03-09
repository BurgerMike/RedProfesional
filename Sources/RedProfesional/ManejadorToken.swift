//
//  ManejadorToken.swift
//  RedProfesional
//

import Foundation

/// Protocolo para manejar el ciclo de vida del token de autenticación.
///
/// Impleméntalo en tu app para habilitar el refresh automático de tokens.
/// El cliente lo llamará automáticamente cuando reciba un `401 Unauthorized`.
///
/// ### Ejemplo con un endpoint de refresh estándar
/// ```swift
/// actor TokenManager: ManejadorToken {
///     private var refreshToken: String
///     private let cliente: ClienteHTTP
///
///     init(refreshToken: String, cliente: ClienteHTTP) {
///         self.refreshToken = refreshToken
///         self.cliente = cliente
///     }
///
///     func refrescarToken() async throws -> String {
///         struct Body: Encodable { let refreshToken: String }
///         struct Respuesta: Decodable { let accessToken: String }
///
///         let respuesta: Respuesta = try await cliente.request(
///             endpoint: Endpoint(path: "auth/refresh", metodo: .post),
///             tipo: Respuesta.self,
///             body: Body(refreshToken: refreshToken)
///         )
///         return respuesta.accessToken
///     }
/// }
/// ```
///
/// ### Registro en el cliente
/// ```swift
/// var cliente = ClienteHTTP(baseURL: url)
/// cliente.manejadorToken = TokenManager(refreshToken: "...", cliente: cliente)
/// ```
public protocol ManejadorToken: Sendable {
    /// Renueva el token de acceso y devuelve el nuevo valor.
    ///
    /// - Throws: Cualquier error si el refresh falla (p. ej. refresh token expirado).
    ///   En ese caso el cliente propagará el error original 401 sin reintentar.
    func refrescarToken() async throws -> String
}
