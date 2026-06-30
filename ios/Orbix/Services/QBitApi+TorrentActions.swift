import Foundation

extension QBitApi {
    func setFilePriorities(_ hash: String, indices: [Int], priority: Int) async throws {
        let _ = try await authedPost("/api/v2/torrents/filePrio", body: [
            "hash": hash,
            "id": indices.map(String.init).joined(separator: "|"),
            "priority": "\(priority)"
        ])
    }

    func addTrackers(_ hash: String, urls: [String]) async throws {
        let _ = try await authedPost("/api/v2/torrents/addTrackers", body: [
            "hash": hash,
            "urls": urls.joined(separator: "\n")
        ])
    }

    func removeTrackers(_ hash: String, urls: [String]) async throws {
        let _ = try await authedPost("/api/v2/torrents/removeTrackers", body: [
            "hash": hash,
            "urls": urls.joined(separator: "|")
        ])
    }

    func startTorrent(_ hash: String) async throws {
        let _ = try await authedPost("/api/v2/torrents/start", body: ["hashes": hash])
    }

    func stopTorrent(_ hash: String) async throws {
        let _ = try await authedPost("/api/v2/torrents/stop", body: ["hashes": hash])
    }

    func forceStartTorrent(_ hash: String) async throws {
        let _ = try await authedPost("/api/v2/torrents/setForceStart", body: ["hashes": hash, "value": "true"])
    }

    func recheckTorrent(_ hash: String) async throws {
        let _ = try await authedPost("/api/v2/torrents/recheck", body: ["hashes": hash])
    }

    func reannounceTorrent(_ hash: String) async throws {
        let _ = try await authedPost("/api/v2/torrents/reannounce", body: ["hashes": hash])
    }

    func deleteTorrent(_ hash: String, deleteFiles: Bool) async throws {
        let _ = try await authedPost("/api/v2/torrents/delete", body: [
            "hashes": hash,
            "deleteFiles": deleteFiles ? "true" : "false"
        ])
    }

    func setTorrentLocation(_ hash: String, location: String) async throws {
        let _ = try await authedPost("/api/v2/torrents/setLocation", body: [
            "hashes": hash,
            "location": location
        ])
    }

    func renameTorrent(_ hash: String, name: String) async throws {
        let _ = try await authedPost("/api/v2/torrents/rename", body: [
            "hash": hash,
            "name": name
        ])
    }

    func setTorrentDownloadLimit(_ hash: String, limit: Int64) async throws {
        let _ = try await authedPost("/api/v2/torrents/setDownloadLimit", body: [
            "hashes": hash,
            "limit": "\(limit)"
        ])
    }

    func setTorrentUploadLimit(_ hash: String, limit: Int64) async throws {
        let _ = try await authedPost("/api/v2/torrents/setUploadLimit", body: [
            "hashes": hash,
            "limit": "\(limit)"
        ])
    }

    func toggleSequentialDownload(_ hash: String) async throws {
        let _ = try await authedPost("/api/v2/torrents/toggleSequentialDownload", body: [
            "hashes": hash
        ])
    }

    func addMagnet(_ urls: [String], category: String? = nil, tags: String? = nil, savePath: String? = nil) async throws -> String? {
        guard let url = apiUrl("/api/v2/torrents/add") else { throw ApiError.invalidURL }

        var body: [String: String] = ["urls": urls.joined(separator: "\n")]
        if let category = category, !category.isEmpty { body["category"] = category }
        if let tags = tags, !tags.isEmpty { body["tags"] = tags }
        if let savePath = savePath, !savePath.isEmpty { body["savepath"] = savePath }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        if let server = activeServer {
            req.setValue(server.url, forHTTPHeaderField: "Origin")
            req.setValue("\(server.url)/", forHTTPHeaderField: "Referer")
        }
        req.timeoutInterval = 30

        let bodyStr = body.map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")" }.joined(separator: "&")
        req.httpBody = bodyStr.data(using: .utf8)

        let (data, response) = try await session.data(for: req)
        try checkAuth(response: response)
        return String(data: data, encoding: .utf8)
    }

    func addTorrent(bytes: Data, filename: String, category: String? = nil, tags: String? = nil, savePath: String? = nil) async throws -> String? {
        let path = "/api/v2/torrents/add"

        let boundary = "Boundary-\(UUID().uuidString)"
        var multipartData = Data()

        multipartData.append("--\(boundary)\r\n".data(using: .utf8)!)
        multipartData.append("Content-Disposition: form-data; name=\"torrents\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        multipartData.append("Content-Type: application/x-bittorrent\r\n\r\n".data(using: .utf8)!)
        multipartData.append(bytes)
        multipartData.append("\r\n".data(using: .utf8)!)

        if let category = category, !category.isEmpty {
            appendFormField(&multipartData, boundary: boundary, name: "category", value: category)
        }
        if let tags = tags, !tags.isEmpty {
            appendFormField(&multipartData, boundary: boundary, name: "tags", value: tags)
        }
        if let savePath = savePath, !savePath.isEmpty {
            appendFormField(&multipartData, boundary: boundary, name: "savepath", value: savePath)
        }

        multipartData.append("--\(boundary)--\r\n".data(using: .utf8)!)

        return try await authedPostData(path, multipartData: multipartData, boundary: boundary).utf8String
    }

    private func appendFormField(_ data: inout Data, boundary: String, name: String, value: String) {
        data.append("--\(boundary)\r\n".data(using: .utf8)!)
        data.append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".data(using: .utf8)!)
        data.append("\(value)\r\n".data(using: .utf8)!)
    }
}
