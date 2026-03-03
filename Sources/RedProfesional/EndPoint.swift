//
//  EndPoint.swift
//  RedProfesional
//
//  Created by ChumBucketComputer on 03/03/26.
//

import Foundation

/// Describe un endpoint: ruta, método, query, headers y timeout.
public struct Endpoint: Sendable {

    public enum Metodo: String, Sendable {
        case get = "GET"
        case post = "POST"
        case put = "PUT"
        case patch = "PATCH"
        case delete = "DELETE"
    }

    /// Ruta relativa al baseURL. Recomendado: sin slash inicial. Ej: "api/login"
    public var path: String

    public var metodo: Metodo
    public var query: [String: String]
    public var headers: [String: String]
    public var timeout: TimeInterval?

    public init(
        path: String,
        metodo: Metodo = .get,
        query: [String: String] = [:],
        headers: [String: String] = [:],
        timeout: TimeInterval? = nil
    ) {
        self.path = path
        self.metodo = metodo
        self.query = query
        self.headers = headers
        self.timeout = timeout
    }
}
