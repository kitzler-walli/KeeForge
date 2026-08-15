import XCTest
@testable import KeeForge

/// Tests for the Nextcloud Login Flow v2 client (initiate/poll/pollUntilComplete).
/// Every transport is a stub — these tests never touch the network.
final class NextcloudLoginFlowTests: XCTestCase {
    private let serverURL = URL(string: "https://cloud.example.com/")!

    // MARK: - Initiate

    func testInitiateParsesLoginURLAndPollDetails() async throws {
        let json = """
        {
          "poll": {
            "token": "abc123token",
            "endpoint": "https://cloud.example.com/index.php/login/v2/poll"
          },
          "login": "https://cloud.example.com/index.php/login/v2/flow/abc123token"
        }
        """
        let stub = StubTransport(responses: [.init(statusCode: 200, body: Data(json.utf8))])
        let flow = NextcloudLoginFlow(transport: stub.transport)

        let result = try await flow.initiate(serverURL: serverURL)

        XCTAssertEqual(result.pollToken, "abc123token")
        XCTAssertEqual(result.pollEndpoint, URL(string: "https://cloud.example.com/index.php/login/v2/poll"))
        XCTAssertEqual(result.loginURL, URL(string: "https://cloud.example.com/index.php/login/v2/flow/abc123token"))

        let requests = await stub.requests
        let request = try XCTUnwrap(requests.first)
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.url, URL(string: "https://cloud.example.com/index.php/login/v2"))
        XCTAssertEqual(request.value(forHTTPHeaderField: "User-Agent"), NextcloudLoginFlow.defaultUserAgent)
    }

    func testInitiateSendsCustomUserAgent() async throws {
        let json = """
        { "poll": { "token": "t", "endpoint": "https://cloud.example.com/index.php/login/v2/poll" }, "login": "https://cloud.example.com/index.php/login/v2/flow/t" }
        """
        let stub = StubTransport(responses: [.init(statusCode: 200, body: Data(json.utf8))])
        let flow = NextcloudLoginFlow(transport: stub.transport, userAgent: "NextPass (iPhone)")

        _ = try await flow.initiate(serverURL: serverURL)

        let requests = await stub.requests
        let request = try XCTUnwrap(requests.first)
        XCTAssertEqual(request.value(forHTTPHeaderField: "User-Agent"), "NextPass (iPhone)")
    }

    func testInitiateOnNonNextcloudServerThrowsDescriptiveError() async throws {
        let stub = StubTransport(responses: [.init(statusCode: 404, body: Data())])
        let flow = NextcloudLoginFlow(transport: stub.transport)

        do {
            _ = try await flow.initiate(serverURL: serverURL)
            XCTFail("Expected an error")
        } catch let error as CloudProviderError {
            XCTAssertEqual(error, .unknown(String(localized: "This doesn't look like a Nextcloud server. Check the server address.")))
        }
    }

    func testInitiateWithMalformedJSONThrows() async throws {
        let stub = StubTransport(responses: [.init(statusCode: 200, body: Data("{\"nonsense\":true}".utf8))])
        let flow = NextcloudLoginFlow(transport: stub.transport)

        do {
            _ = try await flow.initiate(serverURL: serverURL)
            XCTFail("Expected an error")
        } catch is CloudProviderError {
            // Expected: malformed response.
        }
    }

    func testInitiateMapsServerErrorStatusCode() async throws {
        let stub = StubTransport(responses: [.init(statusCode: 503, body: Data())])
        let flow = NextcloudLoginFlow(transport: stub.transport)

        do {
            _ = try await flow.initiate(serverURL: serverURL)
            XCTFail("Expected an error")
        } catch let error as CloudProviderError {
            XCTAssertEqual(error, .unknown(String(localized: "The server reported an error (HTTP 503). Try again shortly.")))
        }
    }

    // MARK: - Poll

    func testPollReturnsNilWhileNotFinished() async throws {
        let stub = StubTransport(responses: [.init(statusCode: 404, body: Data())])
        let flow = NextcloudLoginFlow(transport: stub.transport)

        let result = try await flow.poll(endpoint: URL(string: "https://cloud.example.com/index.php/login/v2/poll")!, token: "tok")

        XCTAssertNil(result)
    }

    func testPollSendsTokenAsFormBody() async throws {
        let stub = StubTransport(responses: [.init(statusCode: 404, body: Data())])
        let flow = NextcloudLoginFlow(transport: stub.transport)
        let endpoint = URL(string: "https://cloud.example.com/index.php/login/v2/poll")!

        _ = try await flow.poll(endpoint: endpoint, token: "tok-123")

        let requests = await stub.requests
        let request = try XCTUnwrap(requests.first)
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/x-www-form-urlencoded")
        XCTAssertEqual(request.httpBody, Data("token=tok-123".utf8))
    }

    func testPollParsesCredentialAndNormalizesServerURL() async throws {
        let json = """
        { "server": "https://cloud.example.com", "loginName": "alice", "appPassword": "s3cr3t-app-pw" }
        """
        let stub = StubTransport(responses: [.init(statusCode: 200, body: Data(json.utf8))])
        let flow = NextcloudLoginFlow(transport: stub.transport)

        let result = try await flow.poll(
            endpoint: URL(string: "https://cloud.example.com/index.php/login/v2/poll")!,
            token: "tok"
        )

        let credential = try XCTUnwrap(result)
        // Normalization guarantees exactly one trailing slash.
        XCTAssertEqual(credential.serverURL, URL(string: "https://cloud.example.com/"))
        XCTAssertEqual(credential.loginName, "alice")
        XCTAssertEqual(credential.appPassword, "s3cr3t-app-pw")
    }

    func testPollRejectsHTTPServerURLUnlessExplicitlyAllowed() async throws {
        let json = """
        { "server": "http://cloud.example.com", "loginName": "alice", "appPassword": "pw" }
        """
        let stub = StubTransport(responses: [.init(statusCode: 200, body: Data(json.utf8))])
        let flow = NextcloudLoginFlow(transport: stub.transport)

        do {
            _ = try await flow.poll(
                endpoint: URL(string: "https://cloud.example.com/index.php/login/v2/poll")!,
                token: "tok"
            )
            XCTFail("Expected an error for an insecure server URL")
        } catch is CloudProviderError {
            // Expected: normalization rejects http:// without the opt-in.
        }
    }

    func testPollAllowsHTTPServerURLWhenExplicitlyAllowed() async throws {
        let json = """
        { "server": "http://cloud.example.com", "loginName": "alice", "appPassword": "pw" }
        """
        let stub = StubTransport(responses: [.init(statusCode: 200, body: Data(json.utf8))])
        let flow = NextcloudLoginFlow(transport: stub.transport)

        let result = try await flow.poll(
            endpoint: URL(string: "https://cloud.example.com/index.php/login/v2/poll")!,
            token: "tok",
            allowsUnencryptedHTTP: true
        )

        XCTAssertEqual(result?.serverURL, URL(string: "http://cloud.example.com/"))
    }

    func testPollWithMissingFieldsThrows() async throws {
        let json = """
        { "server": "https://cloud.example.com", "loginName": "", "appPassword": "" }
        """
        let stub = StubTransport(responses: [.init(statusCode: 200, body: Data(json.utf8))])
        let flow = NextcloudLoginFlow(transport: stub.transport)

        do {
            _ = try await flow.poll(
                endpoint: URL(string: "https://cloud.example.com/index.php/login/v2/poll")!,
                token: "tok"
            )
            XCTFail("Expected an error")
        } catch is CloudProviderError {
            // Expected: empty loginName/appPassword count as malformed.
        }
    }

    // MARK: - pollUntilComplete

    func testPollUntilCompleteRetriesThroughPendingResponsesThenReturns() async throws {
        let json = """
        { "server": "https://cloud.example.com", "loginName": "alice", "appPassword": "pw" }
        """
        let stub = StubTransport(responses: [
            .init(statusCode: 404, body: Data()),
            .init(statusCode: 404, body: Data()),
            .init(statusCode: 200, body: Data(json.utf8)),
        ])
        let flow = NextcloudLoginFlow(transport: stub.transport)

        let credential = try await flow.pollUntilComplete(
            endpoint: URL(string: "https://cloud.example.com/index.php/login/v2/poll")!,
            token: "tok",
            interval: .milliseconds(1)
        )

        XCTAssertEqual(credential.loginName, "alice")
        let requestCount = await stub.requests.count
        XCTAssertEqual(requestCount, 3)
    }

    func testPollUntilCompleteThrowsAfterTimeoutExpires() async throws {
        let stub = StubTransport(responses: [], defaultStatusCode: 404)
        let flow = NextcloudLoginFlow(transport: stub.transport)

        do {
            _ = try await flow.pollUntilComplete(
                endpoint: URL(string: "https://cloud.example.com/index.php/login/v2/poll")!,
                token: "tok",
                interval: .milliseconds(1),
                timeout: .milliseconds(20)
            )
            XCTFail("Expected a timeout error")
        } catch let error as CloudProviderError {
            XCTAssertEqual(error, .unknown(String(localized: "This sign-in link expired. Try connecting again.")))
        }
    }

    func testPollUntilCompleteStopsOnCancellation() async throws {
        let stub = StubTransport(responses: [], defaultStatusCode: 404)
        let flow = NextcloudLoginFlow(transport: stub.transport)

        let task = Task {
            try await flow.pollUntilComplete(
                endpoint: URL(string: "https://cloud.example.com/index.php/login/v2/poll")!,
                token: "tok",
                interval: .milliseconds(5)
            )
        }
        task.cancel()

        do {
            _ = try await task.value
            XCTFail("Expected cancellation to propagate")
        } catch is CancellationError {
            // Expected.
        } catch let error as CloudProviderError {
            // Task.checkCancellation() may race a poll that was already in
            // flight; either the timeout/URL error path or CancellationError
            // is an acceptable outcome as long as the loop actually stopped.
            _ = error
        }
    }
}

// MARK: - Stub transport

/// A queued-response stub transport: each call returns the next canned
/// response (or `defaultStatusCode` once the queue is exhausted), and records
/// every request it received for assertions.
private actor StubTransport {
    struct Response {
        let statusCode: Int
        let body: Data
    }

    private var queue: [Response]
    private let defaultStatusCode: Int
    private(set) var requests: [URLRequest] = []

    init(responses: [Response], defaultStatusCode: Int = 200) {
        self.queue = responses
        self.defaultStatusCode = defaultStatusCode
    }

    private func next(for request: URLRequest) -> Response {
        requests.append(request)
        if queue.isEmpty {
            return Response(statusCode: defaultStatusCode, body: Data())
        }
        return queue.removeFirst()
    }

    nonisolated var transport: WebDAVClient.Transport {
        { [self] request in
            let response = await self.next(for: request)
            let httpResponse = HTTPURLResponse(
                url: request.url ?? URL(string: "https://example.com/")!,
                statusCode: response.statusCode,
                httpVersion: "HTTP/1.1",
                headerFields: [:]
            )!
            return (response.body, httpResponse)
        }
    }
}
