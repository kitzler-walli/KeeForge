#if os(macOS)
import Foundation
import Network
import os

/// The app end of the browser bridge: a minimal HTTP endpoint on
/// 127.0.0.1:`port`, so the extension connects to a running NextPass with
/// nothing installed in the browser. Each request is a `POST` of one JSON
/// message, answered by `BrowserBridgeRequestHandler`.
///
/// Only the NextPass extension gets through: the browser stamps an extension's
/// requests with `Origin: chrome-extension://<id>`, which no web page can
/// forge, and anything else is refused before the handler sees it.
final class BrowserBridgeServer: @unchecked Sendable {
    /// Fixed so the extension knows where to look; `BrowserExtension/popup.js`
    /// uses the same number.
    static let port: UInt16 = 19735

    private let allowedOrigin: String
    private let handle: @MainActor @Sendable (Data) async -> Data
    private let queue = DispatchQueue(label: "at.kw.nextpass.browser-bridge")
    private var listener: NWListener?

    private static let logger = Logger(subsystem: "NextPass", category: "BrowserBridge")

    init(extensionID: String, handle: @escaping @MainActor @Sendable (Data) async -> Data) {
        allowedOrigin = "chrome-extension://\(extensionID)"
        self.handle = handle
    }

    func start() {
        let parameters = NWParameters.tcp
        parameters.requiredLocalEndpoint = .hostPort(host: .ipv4(.loopback), port: NWEndpoint.Port(rawValue: Self.port) ?? .any)
        do {
            let listener = try NWListener(using: parameters)
            listener.newConnectionHandler = { [weak self] connection in
                self?.serve(connection)
            }
            listener.stateUpdateHandler = { state in
                if case .failed(let error) = state {
                    Self.logger.error("Browser bridge stopped: \(error.localizedDescription, privacy: .public)")
                }
            }
            listener.start(queue: queue)
            self.listener = listener
        } catch {
            Self.logger.error("Browser bridge could not listen: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func serve(_ connection: NWConnection) {
        connection.start(queue: queue)
        receive(on: connection, buffer: Data())
    }

    private func receive(on connection: NWConnection, buffer: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) { [weak self] data, _, isComplete, error in
            guard let self else { return connection.cancel() }
            var buffer = buffer
            if let data { buffer.append(data) }

            switch BrowserBridgeHTTP.parse(buffer) {
            case .incomplete where error == nil && isComplete == false:
                receive(on: connection, buffer: buffer)
            case .complete(let request):
                respond(to: request, on: connection)
            case .incomplete, .invalid:
                send(BrowserBridgeHTTP.response(status: 400, body: Data()), on: connection)
            }
        }
    }

    private func respond(to request: BrowserBridgeHTTP.Request, on connection: NWConnection) {
        guard request.method == "POST", request.headers["origin"] == allowedOrigin else {
            send(BrowserBridgeHTTP.response(status: 403, body: Data()), on: connection)
            return
        }
        let handle = handle
        Task { @MainActor in
            let body = await handle(request.body)
            self.send(BrowserBridgeHTTP.response(status: 200, body: body), on: connection)
        }
    }

    private func send(_ response: Data, on connection: NWConnection) {
        connection.send(content: response, completion: .contentProcessed { _ in
            connection.cancel()
        })
    }
}

/// Just enough HTTP/1.1 for one request per connection. Pure, for tests.
enum BrowserBridgeHTTP {
    /// Requests are single small JSON messages; anything larger is refused.
    static let maxRequestBytes = 64 * 1024

    struct Request: Equatable {
        let method: String
        /// Lowercased names.
        let headers: [String: String]
        let body: Data
    }

    enum ParseResult: Equatable {
        case incomplete
        case invalid
        case complete(Request)
    }

    static func parse(_ data: Data) -> ParseResult {
        guard data.count <= maxRequestBytes else { return .invalid }
        guard let headerEnd = data.range(of: Data("\r\n\r\n".utf8)) else { return .incomplete }
        guard let head = String(data: data[..<headerEnd.lowerBound], encoding: .utf8) else { return .invalid }

        var lines = head.components(separatedBy: "\r\n")
        let requestLine = lines.removeFirst().split(separator: " ")
        guard requestLine.count == 3 else { return .invalid }

        var headers: [String: String] = [:]
        for line in lines {
            guard let colon = line.firstIndex(of: ":") else { return .invalid }
            let name = line[..<colon].trimmingCharacters(in: .whitespaces).lowercased()
            headers[name] = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
        }

        let length = Int(headers["content-length"] ?? "0") ?? -1
        guard length >= 0 else { return .invalid }
        let body = data[headerEnd.upperBound...]
        guard body.count >= length else { return .incomplete }
        return .complete(Request(method: String(requestLine[0]), headers: headers, body: Data(body.prefix(length))))
    }

    static func response(status: Int, body: Data) -> Data {
        let reason = switch status {
        case 200: "OK"
        case 403: "Forbidden"
        default: "Bad Request"
        }
        var response = Data("HTTP/1.1 \(status) \(reason)\r\nContent-Type: application/json\r\nContent-Length: \(body.count)\r\nConnection: close\r\n\r\n".utf8)
        response.append(body)
        return response
    }
}
#endif
