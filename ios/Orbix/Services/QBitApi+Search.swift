import Foundation

extension QBitApi {
    func getSearchPlugins() async throws -> [SearchPlugin] {
        let data = try await authedGetData("/api/v2/search/plugins")
        return (try? decoder.decode([SearchPlugin].self, from: data)) ?? []
    }

    func startSearch(pattern: String, plugins: [String] = ["all"], category: String? = nil) async throws -> Int? {
        var body: [String: String] = ["pattern": pattern, "plugins": plugins.joined(separator: "\n")]
        if let category = category { body["category"] = category }
        let data = try await authedPost("/api/v2/search/start", body: body)
        let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        return json?["id"] as? Int
    }

    func getSearchStatus(id: Int) async throws -> [String: Any]? {
        let data = try await authedGetData("/api/v2/search/status?id=\(id)")
        let json = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]]
        return json?.first
    }

    func getSearchResults(id: Int, limit: Int = 50, offset: Int = 0) async throws -> [SearchResult] {
        let data = try await authedGetData("/api/v2/search/results?id=\(id)&limit=\(limit)&offset=\(offset)")
        let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        let results = json?["results"] as? [[String: Any]] ?? []
        return results.compactMap { dict in
            guard let num = dict["num"] as? Int,
                  let descr = dict["descr"] as? String,
                  let fileName = dict["fileName"] as? String else { return nil }
            return SearchResult(
                num: num,
                descr: descr,
                fileName: fileName,
                fileSize: dict["fileSize"] as? Int ?? 0,
                nbLeechers: dict["nbLeechers"] as? Int ?? 0,
                nbSeeders: dict["nbSeeders"] as? Int ?? 0,
                siteUrl: dict["siteUrl"] as? String ?? ""
            )
        }
    }

    func stopSearch(id: Int) async throws {
        let _ = try await authedPost("/api/v2/search/stop", body: ["id": "\(id)"])
    }

    func deleteSearch(id: Int) async throws {
        let _ = try await authedPost("/api/v2/search/delete", body: ["id": "\(id)"])
    }
}
