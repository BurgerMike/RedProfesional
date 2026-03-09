# Changelog

Todos los cambios notables de este proyecto se documentan en este archivo.
El formato sigue [Keep a Changelog](https://keepachangelog.com/es/1.1.0/),
y este proyecto adhiere a [Semantic Versioning](https://semver.org/lang/es/).

---

## [Unreleased]

### Added
- **Refresh token automático** — si el servidor responde `401`, el cliente llama a
  `ManejadorToken.refrescarToken()`, actualiza `token` y reintenta la petición original.
  El usuario nunca ve el error. Protocolo `ManejadorToken` inyectable.
- **Interceptores** (`Interceptor`) — lógica transversal antes/después de cada petición:
  headers globales, firmas HMAC, métricas. `ClienteHTTP.interceptores: [any Interceptor]`.
  Implementaciones por defecto vacías: solo sobreescribe lo que necesitas.
- **Cancelación de peticiones** — `cancelar(requestId:)` y `cancelarTodo()` cancelan
  `Task`s activos por su `requestId`.
- **Cache HTTP** — `Endpoint.politicaCache` por petición + helpers `Endpoint.sinCache(path:)`
  y `Endpoint.soloCache(path:)`. Métodos `configurarCache(memoriaBytes:discoBytes:)` y
  `limpiarCache()` en el cliente. Soporta ETags y `304 Not Modified` via `URLCache`.
- `ClienteHTTP` cambiado de `struct` a `final class` con `Locked<T>` para propiedades
  mutables thread-safe (compatible con Swift 6 strict concurrency).
- Helper privado `log(_:_:)` — elimina duplicación del logger en todos los métodos.

### Changed
- `PoliticaReintentos.jitter` — ruido aleatorio ±25% en el backoff exponencial.
- `PoliticaReintentos.maxDelay` — límite superior al delay (default 30 s).
- `PoliticaReintentos.codigosHTTPReintentables` — configura qué códigos HTTP se reintentan.
- `PoliticaReintentos.default` y `.ninguno` como presets estáticos.
- `LoggerConsola` usa `os.Logger` (unified logging) — visible en Console.app e Instruments.
- `LoggerMultiplex` — reenvía a múltiples loggers a la vez.
- `RespuestaCruda.esExitoso`, `header(_:)` e init público para tests.
- Soporte para tvOS 17+, watchOS 10+, visionOS 1+.

---

## [1.0.0] — 2026-03-03

### Added
- `ClienteHTTP` con async/await, `Sendable`, reintentos, logging y datos crudos.
- `Endpoint`, `RespuestaCruda`, `ErrorRed`, `LoggerRed`, `PoliticaReintentos`.
- Compatible con iOS 17+ y macOS 14+. Sin dependencias externas.
