//
//  EndPoint.swift
//  RedProfesional
//

import Foundation

/// Describe un endpoint HTTP: ruta, método, query, headers, timeout y política de cache.
public struct Endpoint: Sendable {

    // MARK: - Método HTTP

    public enum Metodo: String, Sendable {
        case get    = "GET"
        case post   = "POST"
        case put    = "PUT"
        case patch  = "PATCH"
        case delete = "DELETE"
    }

    // MARK: - Propiedades

    /// Ruta relativa al baseURL. Sin slash inicial. Ej: `"usuarios/perfil"`.
    public var path: String

    public var metodo: Metodo

    /// Query parameters añadidos a la URL. Ej: `["pagina": "2", "limite": "20"]`.
    public var query: [String: String]

    /// Headers adicionales específicos de este endpoint.
    /// Sobreescriben los headers base del cliente (ej. `Accept`, `Authorization`).
    public var headers: [String: String]

    /// Timeout en segundos. Si es `nil`, se usa `ClienteHTTP.timeoutPorDefecto`.
    public var timeout: TimeInterval?

    /// Política de cache para esta petición.
    /// Si es `nil`, se usa `.useProtocolCachePolicy` (respeta cabeceras del servidor).
    ///
    /// ### Casos comunes
    /// - `nil` → respeta `Cache-Control` / `ETag` del servidor (recomendado)
    /// - `.reloadIgnoringLocalCacheData` → siempre va al servidor, ignora cache
    /// - `.returnCacheDataElseLoad` → usa cache si existe, sino va al servidor (útil offline)
    /// - `.returnCacheDataDontLoad` → solo cache, nunca red (modo offline estricto)
    public var politicaCache: URLRequest.CachePolicy?

    // MARK: - Init

    public init(
        path: String,
        metodo: Metodo = .get,
        query: [String: String] = [:],
        headers: [String: String] = [:],
        timeout: TimeInterval? = nil,
        politicaCache: URLRequest.CachePolicy? = nil
    ) {
        self.path          = path
        self.metodo        = metodo
        self.query         = query
        self.headers       = headers
        self.timeout       = timeout
        self.politicaCache = politicaCache
    }

    // MARK: - Presets útiles

    /// Endpoint GET que siempre ignora la cache y va al servidor.
    public static func sinCache(path: String, query: [String: String] = [:]) -> Endpoint {
        Endpoint(path: path, query: query, politicaCache: .reloadIgnoringLocalCacheData)
    }

    /// Endpoint GET que usa cache si existe (ideal para modo offline).
    public static func soloCache(path: String, query: [String: String] = [:]) -> Endpoint {
        Endpoint(path: path, query: query, politicaCache: .returnCacheDataDontLoad)
    }
}
