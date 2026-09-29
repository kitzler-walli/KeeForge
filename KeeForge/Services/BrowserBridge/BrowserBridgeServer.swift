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
    /// A client gets this long to deliver a whole request, and at most this
    /// many are served at once, so a local process cannot pile up connections
    /// until NextPass runs out of file descriptors (which would also break
    /// saving). The extension sends one small request and waits.
    static let requestTimeout: DispatchTimeInterval = .seconds(5)
    static let maxConnections = 8

    private let allowedOrigin: String
    private let handle: @MainActor @Sendable (Data) async -> Data
    /// Every piece of mutable state below is touched on this queue only.
    private let queue = DispatchQueue(label: "at.kw.nextpass.browser-bridge")
    private var listener: NWListener?
    private var openConnections = 0

    private static let logger = Logger(subsystem: "NextPass", category: "BrowserBridge")

    init(extensionID: String, handle: @escaping @MainActor @Sendable (Data) async -> Data) {
        allowedOrigin = "chrome-extension://\(extensionID)"
        self.handle = handle
    }

    func start() {
        queue.async { [self] in
            guard listener == nil else { return }
            let parameters = NWParameters.tcp
            parameters.requiredLocalEndpoint = .hostPort(host: .ipv4(.loopback), port: NWEndpoint.Port(rawValue: Self.port) ?? .any)
            do {
                let listener = try NWListener(using: parameters)
                listener.newConnectionHandler = { [weak self] connection in
                    self?.accept(connection)
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
    }

    func stop() {
        queue.async { [self] in
            listener?.cancel()
            listener = nil
        }
    }

    private func accept(_ connection: NWConnection) {
        guard openConnections < Self.maxConnections else {
            connection.cancel()
            return
        }
        openConnections += 1
        let state = ConnectionState(connection: connection) { [weak self] in
            self?.openConnections -= 1
        }
        // Only receiving is timed: a pairing request legitimately waits for
        // the user's click in NextPass before it is answered.
        queue.asyncAfter(deadline: .now() + Self.requestTimeout) {
            if state.hasRequest == false { state.close() }
        }
        connection.start(queue: queue)
        receive(state, buffer: Data())
    }

    private func receive(_ state: ConnectionState, buffer: Data) {
        state.connection.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) { [weak self] data, _, isComplete, error in
            guard let self else { return state.close() }
            var buffer = buffer
            if let data { buffer.append(data) }

            switch BrowserBridgeHTTP.parse(buffer) {
            case .incomplete where error == nil && isComplete == false:
                receive(state, buffer: buffer)
            case .complete(let request):
                state.hasRequest = true
                respond(to: request, state: state)
            case .incomplete, .invalid:
                send(BrowserBridgeHTTP.response(status: 400, body: Data()), state: state)
            }
        }
    }

    private func respond(to request: BrowserBridgeHTTP.Request, state: ConnectionState) {
        guard request.method == "POST", request.headers["origin"] == allowedOrigin else {
            send(BrowserBridgeHTTP.response(status: 403, body: Data()), state: state)
            return
        }
        let handle = handle
        Task { @MainActor in
            let body = await handle(request.body)
            self.queue.async {
                self.send(BrowserBridgeHTTP.response(status: 200, body: body), state: state)
            }
        }
    }

    private func send(_ response: Data, state: ConnectionState) {
        guard state.isClosed == false else { return }
        state.connection.send(content: response, completion: .contentProcessed { _ in
            state.close()
        })
    }

    /// One connection's bookkeeping; used on the server's queue only.
    private final class ConnectionState: @unchecked Sendable {
        let connection: NWConnection
        private let onClose: () -> Void
        var hasRequest = false
        private(set) var isClosed = false

        init(connection: NWConnection, onClose: @escaping () -> Void) {
            self.connection = connection
            self.onClose = onClose
        }

        func close() {
            guard isClosed == false else { return }
            isClosed = true
            connection.cancel()
            onClose()
        }
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
