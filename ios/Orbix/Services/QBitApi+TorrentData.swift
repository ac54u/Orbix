import Foundation

extension QBitApi {
    func getTorrents() async throws -> [TorrentInfo] {
        let data = try await authedGetData("/api/v2/torrents/info")
        return try decoder.decode([TorrentInfo].self, from: data)
    }

    func syncMainData(rid: Int = 0) async throws -> SyncMainData? {
        try await authedGet("/api/v2/sync/maindata?rid=\(rid)", type: SyncMainData.self)
    }

    func getTransferInfo() async throws -> TransferInfo? {
        try await authedGet("/api/v2/transfer/info", type: TransferInfo.self)
    }

    func getAppVersion() async throws -> String? {
        let data = try await authedGetData("/api/v2/app/version")
        return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func getTorrentByHash(_ hash: String) async throws -> TorrentInfo? {
        let data = try await authedGetData("/api/v2/torrents/info?hashes=\(hash)")
        let list = try? decoder.decode([TorrentInfo].self, from: data)
        return list?.first
    }

    func getProperties(_ hash: String) async throws -> TorrentProperties? {
        try await authedGet("/api/v2/torrents/properties?hash=\(hash)", type: TorrentProperties.self)
    }

    func getTorrentFiles(_ hash: String) async throws -> [TorrentFile] {
        let data = try await authedGetData("/api/v2/torrents/files?hash=\(hash)")
        return (try? decoder.decode([TorrentFile].self, from: data)) ?? []
    }

    func getTorrentTrackers(_ hash: String) async throws -> [TorrentTracker] {
        let data = try await authedGetData("/api/v2/torrents/trackers?hash=\(hash)")
        return (try? decoder.decode([TorrentTracker].self, from: data)) ?? []
    }

    func getTorrentPeers(_ hash: String, rid: Int = 0) async throws -> (peers: [TorrentPeer], rid: Int) {
        let data = try await authedGetData("/api/v2/sync/torrentPeers?hash=\(hash)&rid=\(rid)")
        let wrapper = try? decoder.decode(TorrentPeersResponse.self, from: data)
        let all = wrapper?.peers?.map { $0.value } ?? []
        return (peers: all, rid: wrapper?.rid ?? 0)
    }

    func getCategories() async throws -> [String] {
        let data = try await authedGetData("/api/v2/torrents/categories")
        let json = try? JSONSerialization.jsonObject(with: data) as? [String: [String: String]]
        return json?.keys.sorted() ?? []
    }
}
