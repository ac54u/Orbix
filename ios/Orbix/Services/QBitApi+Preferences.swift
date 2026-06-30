import Foundation

extension QBitApi {
    func getPreferences() async throws -> [String: Any] {
        let data = try await authedGetData("/api/v2/app/preferences")
        let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        return json ?? [:]
    }

    func setPreferences(_ json: [String: Any]) async throws {
        let jsonData = try JSONSerialization.data(withJSONObject: json)
        let jsonStr = String(data: jsonData, encoding: .utf8) ?? "{}"
        let _ = try await authedPost("/api/v2/app/setPreferences", body: ["json": jsonStr])
    }

    func setGlobalDownloadLimit(_ limit: Int64) async throws {
        try await setPreferences(["dl_limit": limit])
    }

    func setGlobalUploadLimit(_ limit: Int64) async throws {
        try await setPreferences(["up_limit": limit])
    }

    func toggleSpeedLimitsMode() async throws {
        let _ = try await authedPost("/api/v2/transfer/toggleSpeedLimitsMode", body: [:])
    }
}
