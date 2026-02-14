import Foundation

enum HotkeySide: String, Codable, CaseIterable {
    case right
    case left
    case both
}

struct AppSettings: Codable {
    var appID: String
    var accessToken: String
    var hotkeySide: HotkeySide
    var maxRecordSeconds: Int
    var keepTranscriptionInClipboard: Bool
    var launchAtLogin: Bool
    var logRetentionDays: Int

    static func `default`(fallbackMaxRecordSeconds: Int, env: [String: String]) -> AppSettings {
        AppSettings(
            appID: env["APP_ID"] ?? "",
            accessToken: env["ACCESS_TOKEN"] ?? "",
            hotkeySide: .right,
            maxRecordSeconds: max(30, fallbackMaxRecordSeconds),
            keepTranscriptionInClipboard: true,
            launchAtLogin: false,
            logRetentionDays: 7
        )
    }
}
