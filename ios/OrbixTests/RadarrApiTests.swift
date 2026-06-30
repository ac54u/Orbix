import XCTest
@testable import Orbix
import Foundation

@MainActor
final class RadarrApiTests: XCTestCase {
    var session: URLSession!

    override func setUp() {
        super.setUp()
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        session = URLSession(configuration: config)
        RadarrApi.session = session
        CredentialsManager.shared.radarr = ServiceCredential(
            kind: .radarr, name: "test", host: "test.local", port: 7878,
            https: true, apiKey: "test-key", username: "", password: ""
        )
    }

    override func tearDown() {
        MockURLProtocol.reset()
        RadarrApi.session = .init(configuration: .ephemeral)
        CredentialsManager.shared.radarr = nil
        session = nil
        super.tearDown()
    }

    // MARK: - Lookup

    func testLookup_returnsMappedResults() async throws {
        MockURLProtocol.responseHandler = { request in
            XCTAssertEqual(request.allHTTPHeaderFields?["X-Api-Key"], "test-key")
            XCTAssertTrue(request.url?.absoluteString.contains("/movie/lookup") ?? false)
            let resp = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let json = #"[{"id":123,"title":"Inception","year":2010,"tmdbId":27205,"images":[{"coverType":"poster","remoteUrl":"https://img.local/poster.jpg"}],"hasFile":false}]"#
            return (resp, Data(json.utf8))
        }

        let results = try await RadarrApi.lookup(query: "Inception")
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.fileName, "Inception (2010)")
        XCTAssertEqual(results.first?.siteUrl, "https://img.local/poster.jpg")
    }

    func testLookup_withoutApiKey_throws() async {
        CredentialsManager.shared.radarr = ServiceCredential(
            kind: .radarr, name: "test", host: "test.local", port: 7878,
            https: true, apiKey: "", username: "", password: ""
        )

        do {
            _ = try await RadarrApi.lookup(query: "test")
            XCTFail("Expected unauthorized")
        } catch {}
    }

    func testLookup_non200_throws() async {
        MockURLProtocol.responseHandler = { _ in
            let resp = HTTPURLResponse(url: URL(string: "https://test")!, statusCode: 500, httpVersion: nil, headerFields: nil)!
            return (resp, Data())
        }

        do {
            _ = try await RadarrApi.lookup(query: "test")
            XCTFail("Expected error on 500")
        } catch {}
    }

    // MARK: - getMovies

    func testGetMovies_success() async throws {
        MockURLProtocol.responseHandler = { _ in
            let resp = HTTPURLResponse(url: URL(string: "https://test")!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let json = #"[{"id":1,"title":"Test Movie","year":2024,"overview":"A test","tmdbId":123,"images":[],"hasFile":false}]"#
            return (resp, Data(json.utf8))
        }

        let movies = try await RadarrApi.getMovies()
        XCTAssertEqual(movies.count, 1)
        XCTAssertEqual(movies.first?.title, "Test Movie")
    }

    func testGetMovies_non200_throws() async {
        MockURLProtocol.responseHandler = { _ in
            let resp = HTTPURLResponse(url: URL(string: "https://test")!, statusCode: 401, httpVersion: nil, headerFields: nil)!
            return (resp, Data())
        }

        do {
            _ = try await RadarrApi.getMovies()
            XCTFail("Expected error on 401")
        } catch {}
    }

    // MARK: - getQualityProfiles

    func testGetQualityProfiles_success() async throws {
        MockURLProtocol.responseHandler = { _ in
            let resp = HTTPURLResponse(url: URL(string: "https://test")!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let json = #"[{"id":1,"name":"HD-1080p"},{"id":2,"name":"4K"}]"#
            return (resp, Data(json.utf8))
        }

        let profiles = try await RadarrApi.getQualityProfiles()
        XCTAssertEqual(profiles.count, 2)
        XCTAssertEqual(profiles.first?.name, "HD-1080p")
    }

    // MARK: - getRootFolders

    func testGetRootFolders_success() async throws {
        MockURLProtocol.responseHandler = { _ in
            let resp = HTTPURLResponse(url: URL(string: "https://test")!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let json = #"[{"id":1,"path":"/movies","freeSpace":1000000000}]"#
            return (resp, Data(json.utf8))
        }

        let folders = try await RadarrApi.getRootFolders()
        XCTAssertEqual(folders.count, 1)
        XCTAssertEqual(folders.first?.path, "/movies")
    }

    // MARK: - addMovie

    func testAddMovie_sendsRequest() async throws {
        var requestWasMade = false
        MockURLProtocol.responseHandler = { _ in
            requestWasMade = true
            let resp = HTTPURLResponse(url: URL(string: "https://test.local:7878/api/v3/movie")!, statusCode: 201, httpVersion: nil, headerFields: nil)!
            return (resp, Data())
        }

        try await RadarrApi.addMovie(
            tmdbId: 27205, title: "Inception", year: 2010,
            qualityProfileId: 1, rootFolderPath: "/movies"
        )

        XCTAssertTrue(requestWasMade)
    }

    func testAddMovie_withoutApiKey_noRequestMade() async {
        CredentialsManager.shared.radarr = ServiceCredential(
            kind: .radarr, name: "test", host: "test.local", port: 7878,
            https: true, apiKey: "", username: "", password: ""
        )
        MockURLProtocol.responseHandler = { _ in
            XCTFail("Should not make request")
            throw URLError(.unknown)
        }

        _ = try? await RadarrApi.addMovie(tmdbId: 1, title: "test", year: 2024, qualityProfileId: 1, rootFolderPath: "/")
    }
}
