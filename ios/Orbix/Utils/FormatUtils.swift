import Foundation

func formatSpeed(_ speed: Int64) -> String {
    let kb: Int64 = 1024
    let mb = kb * 1024
    let gb = mb * 1024
    if speed >= gb { return String(format: "%.1f GB/s", Double(speed) / Double(gb)) }
    if speed >= mb { return String(format: "%.1f MB/s", Double(speed) / Double(mb)) }
    if speed >= kb { return String(format: "%.1f KB/s", Double(speed) / Double(kb)) }
    return "\(speed) B/s"
}

func formatBytes(_ bytes: Int64) -> String {
    let kb: Int64 = 1024
    let mb = kb * 1024
    let gb = mb * 1024
    let tb = gb * 1024
    if bytes >= tb { return String(format: "%.2f TB", Double(bytes) / Double(tb)) }
    if bytes >= gb { return String(format: "%.2f GB", Double(bytes) / Double(gb)) }
    if bytes >= mb { return String(format: "%.2f MB", Double(bytes) / Double(mb)) }
    if bytes >= kb { return String(format: "%.2f KB", Double(bytes) / Double(kb)) }
    return "\(bytes) B"
}

func relativeTime(from timestamp: Int64) -> String {
    guard timestamp > 0 else { return "" }
    let interval = Date().timeIntervalSince(Date(timeIntervalSince1970: TimeInterval(timestamp)))
    if interval < 0 { return "" }
    let mins = Int(interval / 60)
    let hours = mins / 60
    let days = hours / 24
    let weeks = days / 7
    let months = days / 30
    let years = days / 365
    if years >= 1 { return String(localized: "\(years)年前") }
    if months >= 1 { return String(localized: "\(months)个月前") }
    if weeks >= 1 { return String(localized: "\(weeks)周前") }
    if days >= 1 { return String(localized: "\(days)天前") }
    if hours >= 1 { return String(localized: "\(hours)小时前") }
    if mins >= 1 { return String(localized: "\(mins)分钟前") }
    return String(localized: "刚刚")
}
