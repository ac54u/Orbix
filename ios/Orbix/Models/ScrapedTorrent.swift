import Foundation

struct ScrapedTorrent: Codable, Identifiable, Equatable {
    var id: String { code }
    let code: String
    let title: String
    let size: String
    let date: String
    let thumbnail: String?
    let magnet: String
    let torrentUrl: String?
    let pageUrl: String?
    let description: String?

    static func == (lhs: ScrapedTorrent, rhs: ScrapedTorrent) -> Bool {
        lhs.code == rhs.code
    }
}

#if DEBUG
extension ScrapedTorrent {
    static func demo() -> ScrapedTorrent {
        ScrapedTorrent(code: "SSIS-001", title: "Sample Title", size: "5.2GB",
                       date: "2026-06-29", thumbnail: nil, magnet: "magnet:?xt=urn:btih:demo",
                       torrentUrl: nil, pageUrl: nil, description: "A sample description.")
    }
}
#endif
