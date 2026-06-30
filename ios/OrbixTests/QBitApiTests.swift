import XCTest
@testable import Orbix
import Foundation

final class QBitApiTests: XCTestCase {
    var session: URLSession!
    var api: QBitApi!

    override func setUp() {
        super.setUp()
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        session = URLSession(configuration: config)
        api = QBitApi(session: session)
    }

    override func tearDown() {
        MockURLProtocol.reset()
        api = nil
        session = nil
        super.tearDown()
    }

    // MARK: - Login

    func testLogin_success() async {
        MockURLProtocol.responseHandler = { request in
            XCTAssertTrue(request.url?.absoluteString.contains("/auth/login") ?? false)
            XCTAssertEqual(request.httpMethod, "POST")
            let resp = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (resp, Data())
        }

        let server = ServerConfig(name: "test", host: "10.0.0.1", port: 8080, username: "admin", password: "pass", https: false)
        let result = await api.login(server: server)
        XCTAssertTrue(result.isSuccess)
    }

    func testLogin_urlEncodesSpecialCharacters() async throws {
        var capturedBody: String?
        MockURLProtocol.responseHandler = { request in
            capturedBody = request.httpBody.flatMap { String(data: $0, encoding: .utf8) }
            let resp = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (resp, Data())
        }

        let server = ServerConfig(name: "test", host: "10.0.0.1", port: 8080, username: "user@name", password: "p&a=s+s%", https: false)
        _ = await api.login(server: server)

        let body = try XCTUnwrap(capturedBody)
        XCTAssertFalse(body.contains("p&a=s+s%"), "Password special chars must be percent-encoded")
        XCTAssertTrue(body.contains("username=user%40name") || body.contains("username=user@name"))
    }

    func testLogin_authFailed_403() async {
        MockURLProtocol.responseHandler = { request in
            let resp = HTTPURLResponse(url: request.url!, statusCode: 403, httpVersion: nil, headerFields: nil)!
            return (resp, Data())
        }

        let server = ServerConfig(name: "test", host: "10.0.0.1", port: 8080, username: "admin", password: "wrong", https: false)
        let result = await api.login(server: server)
        XCTAssertEqual(result.status, .authFailed)
    }

    func testLogin_networkError_retriesTwice() async {
        var attemptCount = 0
        MockURLProtocol.responseHandler = { _ in
            attemptCount += 1
            throw URLError(.notConnectedToInternet)
        }

        let server = ServerConfig(name: "test", host: "10.0.0.1", port: 8080, username: "u", password: "p", https: false)
        let result = await api.login(server: server)
        XCTAssertEqual(result.status, .network)
        XCTAssertEqual(attemptCount, 2)
    }

    func testLogin_invalidURL() async {
        MockURLProtocol.responseHandler = { _ in
            XCTFail("Should not be called")
            throw URLError(.badURL)
        }

        let server = ServerConfig(name: "test", host: "", port: 0, username: "", password: "", https: false)
        let result = await api.login(server: server)
        XCTAssertEqual(result.status, .unknown)
    }

    // MARK: - authedGet

    func testAuthedGet_success() async throws {
        let server = ServerConfig(name: "test", host: "10.0.0.1", port: 8080, username: "u", password: "p", https: false)
        await api.setActiveServer(server)
        _ = await api.login(server: server)

        MockURLProtocol.responseHandler = { request in
            let resp = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
            let json = #"[{"hash":"abc","name":"test","state":"downloading","progress":0.5,"dlspeed":0,"upspeed":0,"size":1000}]"#
            return (resp, Data(json.utf8))
        }

        let torrents: [TorrentInfo]? = try await api.authedGet("/api/v2/torrents/info", type: [TorrentInfo].self)
        XCTAssertNotNil(torrents)
        XCTAssertEqual(torrents?.count, 1)
        XCTAssertEqual(torrents?.first?.hash, "abc")
    }

    func testAuthedGet_invalidURL_throws() async {
        do {
            _ = try await api.authedGet("/test", type: [TorrentInfo].self) as [TorrentInfo]?
            XCTFail("Expected error")
        } catch is ApiError {
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testAuthedGet_401triggersRenewal() async {
        var calls = 0
        MockURLProtocol.responseHandler = { request in
            calls += 1
            if request.url?.absoluteString.contains("/auth/login") == true {
                let resp = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
                return (resp, Data())
            }
            let resp = HTTPURLResponse(url: request.url!, statusCode: 401, httpVersion: nil, headerFields: nil)!
            return (resp, Data())
        }

        let server = ServerConfig(name: "test", host: "10.0.0.1", port: 8080, username: "u", password: "p", https: false)
        await api.setActiveServer(server)

        do {
            _ = try await api.authedGet("/test", type: [TorrentInfo].self) as [TorrentInfo]?
        } catch {}

        await Task.yield()
        XCTAssertGreaterThanOrEqual(calls, 2, "Should attempt renewal after 401")
    }

    func testAuthedGet_retriesOnNetworkError() async {
        var attempts = 0
        MockURLProtocol.responseHandler = { _ in
            attempts += 1
            throw URLError(.timedOut)
        }

        let server = ServerConfig(name: "test", host: "10.0.0.1", port: 8080, username: "u", password: "p", https: false)
        await api.setActiveServer(server)

        do {
            _ = try await api.authedGet("/test", type: [TorrentInfo].self) as [TorrentInfo]?
        } catch {}
        XCTAssertEqual(attempts, 2)
    }

    func testAuthedGet_emptyResponse() async throws {
        MockURLProtocol.stubJSON("[]", status: 200)

        let server = ServerConfig(name: "test", host: "10.0.0.1", port: 8080, username: "u", password: "p", https: false)
        await api.setActiveServer(server)

        let result: [TorrentInfo]? = try await api.authedGet("/test", type: [TorrentInfo].self)
        XCTAssertEqual(result?.count, 0)
    }

    // MARK: - URL Building

    func testBuildUrl_simple() {
        let url = QBitApi.buildUrl(host: "10.0.0.1", port: 8080, https: false)
        XCTAssertEqual(url, "http://10.0.0.1:8080")
    }

    func testBuildUrl_https() {
        let url = QBitApi.buildUrl(host: "nas.local", port: 443, https: true)
        XCTAssertEqual(url, "https://nas.local:443")
    }

    func testBuildUrl_hostWithScheme_usesExplicitHttps() {
        let url = QBitApi.buildUrl(host: "http://10.0.0.1:8080", port: 8080, https: true)
        XCTAssertTrue(url.hasPrefix("https://"))
    }

    func testBuildUrl_stripsTrailingSlash() {
        let url = QBitApi.buildUrl(host: "https://example.com/", port: 443, https: false)
        XCTAssertFalse(url.hasSuffix("/"))
    }
}
