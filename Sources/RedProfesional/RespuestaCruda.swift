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

    // MARK: - Init interno
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
}
