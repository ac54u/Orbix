import XCTest
@testable import Orbix
import Foundation

@MainActor
final class ProwlarrApiTests: XCTestCase {
    var session: URLSession!

    override func setUp() {
        super.setUp()
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        session = URLSession(configuration: config)
        ProwlarrApi.session = session
        CredentialsManager.shared.prowlarr = ServiceCredential(
            kind: .prowlarr, name: "test", host: "test.local", port: 9696,
            https: true, apiKey: "test-key", username: "", password: ""
        )
    }

    override func tearDown() {
        MockURLProtocol.reset()
        ProwlarrApi.session = .init(configuration: .ephemeral)
        CredentialsManager.shared.prowlarr = nil
        session = nil
        super.tearDown()
    }

    // MARK: - Search

    func testSearch_returnsMappedResults() async throws {
        MockURLProtocol.responseHandler = { request in
            XCTAssertEqual(request.allHTTPHeaderFields?["X-Api-Key"], "test-key")
            let resp = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let json = #"[{"guid":"abc123","title":"Ubuntu 24.04 ISO","indexer":"1337x","size":5876543210,"seeders":142,"leechers":38,"downloadUrl":"magnet:?xt=urn:btih:abc123"}]"#
            return (resp, Data(json.utf8))
        }

        let results = try await ProwlarrApi.search(query: "Ubuntu")
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.fileName, "Ubuntu 24.04 ISO")
        XCTAssertEqual(results.first?.nbSeeders, 142)
    }

    func testSearch_withoutApiKey_returnsEmpty() async throws {
        CredentialsManager.shared.prowlarr = ServiceCredential(
            kind: .prowlarr, name: "test", host: "test.local", port: 9696,
            https: true, apiKey: "", username: "", password: ""
        )

        let results = try await ProwlarrApi.search(query: "test")
        XCTAssertTrue(results.isEmpty)
    }

    func testSearch_non200_throws() async {
        MockURLProtocol.responseHandler = { _ in
            let resp = HTTPURLResponse(url: URL(string: "https://test")!, statusCode: 500, httpVersion: nil, headerFields: nil)!
            return (resp, Data())
        }

        do {
            _ = try await ProwlarrApi.search(query: "test")
            XCTFail("Expected error")
        } catch {}
    }

    // MARK: - Stable ID (djb2 hash)

    func testStableId_isDeterministic() async throws {
        MockURLProtocol.responseHandler = { _ in
            let resp = HTTPURLResponse(url: URL(string: "https://test")!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let json = #"[{"guid":"test-guid-abc","title":"Test","indexer":"idx","size":100,"seeders":1,"leechers":0}]"#
            return (resp, Data(json.utf8))
        }

        let first = try await ProwlarrApi.search(query: "test")
        MockURLProtocol.reset()
        MockURLProtocol.responseHandler = { _ in
            let resp = HTTPURLResponse(url: URL(string: "https://test")!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let json = #"[{"guid":"test-guid-abc","title":"Test","indexer":"idx","size":100,"seeders":1,"leechers":0}]"#
            return (resp, Data(json.utf8))
        }

        let second = try await ProwlarrApi.search(query: "test")
        XCTAssertEqual(first.first?.num, second.first?.num, "Same guid should produce same stable id")
    }

    // MARK: - getIndexers

    func testGetIndexers_parsesCorrectly() async throws {
        MockURLProtocol.responseHandler = { _ in
            let resp = HTTPURLResponse(url: URL(string: "https://test")!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let json = #"[{"id":1,"name":"1337x"},{"id":2,"name":"RARBG"}]"#
            return (resp, Data(json.utf8))
        }

        let indexers = try await ProwlarrApi.getIndexers()
        XCTAssertEqual(indexers.count, 2)
        XCTAssertEqual(indexers.first?.name, "1337x")
        XCTAssertEqual(indexers.first?.id, 1)
    }
}
