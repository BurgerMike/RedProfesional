//
//  RespuestaCruda.swift
//  RedProfesional
//

import Foundation

/// Representa la respuesta HTTP completa sin decodificar.
///
/// Úsala cuando necesites:
/// - Inspeccionar qué devuelve exactamente un endpoint.
/// - Guardar la respuesta en SwiftData u otro almacenamiento (usa `data`).
/// - Leer cabeceras de la respuesta (p. ej. `X-Total-Count`, `ETag`).
///
/// ### Guardar en SwiftData (fuera del paquete)
/// ```swift
/// let respuesta = try await cliente.requestCrudo(endpoint: .catalogo)
///
/// // En tu @Model de SwiftData:
/// registro.jsonGuardado  = respuesta.data
/// registro.statusCode    = respuesta.statusCode
/// registro.fechaGuardado = respuesta.fecha
/// ```
public struct RespuestaCruda: Sendable {

    /// Bytes crudos devueltos por el servidor.
    public let data: Data

    /// Código de estado HTTP (p. ej. 200, 201).
    public let statusCode: Int

    /// Cabeceras HTTP de la respuesta.
    public let headers: [String: String]

    /// Momento en que se recibió la respuesta.
    public let fecha: Date

    // MARK: - Inspección

    /// JSON formateado y legible. `nil` si el cuerpo no es JSON válido.
    public var jsonPretty: String? { data.jsonPretty }

    /// Cuerpo como texto UTF-8 sin formato. `nil` si no es texto legible.
    public var utf8String: String? { data.utf8String }

    /// `true` si el cuerpo es JSON válido.
    public var esJSON: Bool { jsonPretty != nil }

    /// Tamaño del cuerpo en bytes.
    public var bytes: Int { data.count }

    /// `true` si el status code está en el rango 2xx.
    public var esExitoso: Bool { (200...299).contains(statusCode) }

    // MARK: - Acceso a cabeceras

    /// Devuelve el valor de la cabecera indicada (búsqueda insensible a mayúsculas).
    ///
    /// ```swift
    /// let total = respuesta.header("X-Total-Count")
    /// let etag  = respuesta.header("ETag")
    /// ```
    public func header(_ nombre: String) -> String? {
        let lower = nombre.lowercased()
        return headers.first { $0.key.lowercased() == lower }?.value
    }

    // MARK: - Inits

    /// Init interno para uso del cliente HTTP.
    init(data: Data, http: HTTPURLResponse) {
        self.data = data
        self.statusCode = http.statusCode
        self.fecha = .now

        var hdrs: [String: String] = [:]
        for (k, v) in http.allHeaderFields {
            if let key = k as? String, let val = v as? String {
                hdrs[key] = val
            }
        }
        self.headers = hdrs
    }

    /// Init público para facilitar tests unitarios.
    ///
    /// ```swift
    /// let mock = RespuestaCruda(
    ///     data: jsonData,
    ///     statusCode: 200,
    ///     headers: ["Content-Type": "application/json"]
    /// )
    /// ```
    public init(data: Data, statusCode: Int, headers: [String: String] = [:], fecha: Date = .now) {
        self.data = data
        self.statusCode = statusCode
        self.headers = headers
        self.fecha = fecha
    }
}
