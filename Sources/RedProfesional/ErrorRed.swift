//
//  ErrorRed.swift
//  RedProfesional
//

//

import Foundation

public enum ErrorRed: Error, LocalizedError, Equatable, CustomStringConvertible {
    // MARK: - Casos principales (cubre URLSession + HTTP + Datos)
    case urlInvalida
    case sinRespuestaHTTP
    case red(tipo: TipoRed, detalle: String? = nil)
    case http(codigo: Int, body: String? = nil)
    case decoding(detalle: String? = nil)
    case encoding(detalle: String? = nil)
    case desconocido(detalle: String? = nil)

    public enum TipoRed: String, Equatable, Sendable {
        case sinInternet
        case timeout
        case cancelado
        case dns
        case conexionPerdida
        case ssl
        case restringido // ej. dataNotAllowed / restricciones
    }

    public static func desde(_ error: Error) -> ErrorRed {
        if let e = error as? ErrorRed { return e }

        if let u = error as? URLError {
            switch u.code {
            case .notConnectedToInternet:
                return .red(tipo: .sinInternet)
            case .timedOut:
                return .red(tipo: .timeout)
            case .cancelled:
                return .red(tipo: .cancelado)
            case .cannotFindHost, .cannotConnectToHost, .dnsLookupFailed:
                return .red(tipo: .dns, detalle: u.localizedDescription)
            case .networkConnectionLost:
                return .red(tipo: .conexionPerdida, detalle: u.localizedDescription)
            case .secureConnectionFailed, .serverCertificateUntrusted, .clientCertificateRejected, .clientCertificateRequired:
                return .red(tipo: .ssl, detalle: u.localizedDescription)
            case .dataNotAllowed:
                return .red(tipo: .restringido, detalle: u.localizedDescription)
            default:
                return .desconocido(detalle: "URLError(\(u.code.rawValue)): \(u.localizedDescription)")
            }
        }

        // Si no es URLError, lo guardamos como desconocido con su descripcion
        return .desconocido(detalle: error.localizedDescription)
    }

    // MARK: - Mensaje para UI (lo que enseñas al usuario)
    public var mensajeUsuario: String {
        switch self {
        case .urlInvalida:
            return "La dirección del servicio es inválida."
        case .sinRespuestaHTTP:
            return "No pude obtener respuesta del servidor."
        case .red(let tipo, _):
            switch tipo {
            case .sinInternet: return "Sin internet. Revisa tu conexión."
            case .timeout: return "Tardó demasiado. Intenta otra vez."
            case .cancelado: return "Se canceló la solicitud."
            case .dns: return "No pude encontrar el servidor."
            case .conexionPerdida: return "Se perdió la conexión."
            case .ssl: return "No se pudo verificar la seguridad del servidor."
            case .restringido: return "Conexión restringida. Revisa tu red o permisos."
            }
        case .http(let codigo, let body):
            switch codigo {
            case 400:
                if let body, body.contains("UserPassIncorrect") { return "Usuario o contraseña incorrectos." }
                return "La solicitud es inválida. Revisa los datos."
            case 401:
                return "Sesión no válida. Inicia sesión de nuevo."
            case 403:
                return "No tienes permisos para esta acción."
            case 404:
                return "No se encontró el recurso."
            case 409:
                return "Conflicto de datos. Intenta otra vez."
            case 413:
                return "El contenido es demasiado grande."
            case 415:
                return "Formato no compatible."
            case 422:
                return "Datos inválidos. Revisa los campos."
            case 429:
                return "Demasiadas solicitudes. Intenta más tarde."
            case 500:
                return "El servidor tuvo un problema. Intenta más tarde."
            case 502, 503, 504:
                return "Servidor no disponible por el momento."
            default:
                if (500...599).contains(codigo) { return "Error del servidor (\(codigo)). Intenta más tarde." }
                return "Ocurrió un error (\(codigo))."
            }
        case .decoding:
            return "No pude leer la respuesta del servidor."
        case .encoding:
            return "No pude preparar los datos para enviar."
        case .desconocido:
            return "Ocurrió un error inesperado."
        }
    }

    // MARK: - Debug (lo que logueas)
    public var detalleDebug: String {
        switch self {
        case .urlInvalida:
            return "URL inválida (construcción de URLComponents/URL)."
        case .sinRespuestaHTTP:
            return "Sin HTTPURLResponse (response no casteable)."
        case .red(let tipo, let detalle):
            return "Red[\(tipo.rawValue)] detalle=\(detalle ?? "nil")"
        case .http(let codigo, let body):
            return "HTTP \(codigo) body=\(body ?? "nil")"
        case .decoding(let detalle):
            return "Decoding detalle=\(detalle ?? "nil")"
        case .encoding(let detalle):
            return "Encoding detalle=\(detalle ?? "nil")"
        case .desconocido(let detalle):
            return "Desconocido detalle=\(detalle ?? "nil")"
        }
    }

    // MARK: - Protocolos
    public var errorDescription: String? { mensajeUsuario }
    public var description: String { detalleDebug }
}
