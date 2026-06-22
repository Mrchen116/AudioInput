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
    var enableDDC: Bool
    var hotwords: [String]

    static func `default`(fallbackMaxRecordSeconds: Int, env: [String: String]) -> AppSettings {
        AppSettings(
            appID: env["APP_ID"] ?? "",
            accessToken: env["ACCESS_TOKEN"] ?? "",
            hotkeySide: .right,
            maxRecordSeconds: max(30, fallbackMaxRecordSeconds),
            keepTranscriptionInClipboard: false,
            launchAtLogin: true,
            logRetentionDays: 7,
            enableDDC: true,
            hotwords: ["Claude Code", "openclaw"]
        )
    }

    init(
        appID: String,
        accessToken: String,
        hotkeySide: HotkeySide,
        maxRecordSeconds: Int,
        keepTranscriptionInClipboard: Bool,
        launchAtLogin: Bool,
        logRetentionDays: Int,
        enableDDC: Bool,
        hotwords: [String]
    ) {
        self.appID = appID
        self.accessToken = accessToken
        self.hotkeySide = hotkeySide
        self.maxRecordSeconds = maxRecordSeconds
        self.keepTranscriptionInClipboard = keepTranscriptionInClipboard
        self.launchAtLogin = launchAtLogin
        self.logRetentionDays = logRetentionDays
        self.enableDDC = enableDDC
        self.hotwords = hotwords
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.appID = try container.decode(String.self, forKey: .appID)
        self.accessToken = try container.decode(String.self, forKey: .accessToken)
        self.hotkeySide = try container.decodeIfPresent(HotkeySide.self, forKey: .hotkeySide) ?? .right
        self.maxRecordSeconds = try container.decodeIfPresent(Int.self, forKey: .maxRecordSeconds) ?? 180
        self.keepTranscriptionInClipboard = try container.decodeIfPresent(Bool.self, forKey: .keepTranscriptionInClipboard) ?? false
        self.launchAtLogin = try container.decodeIfPresent(Bool.self, forKey: .launchAtLogin) ?? true
        self.logRetentionDays = try container.decodeIfPresent(Int.self, forKey: .logRetentionDays) ?? 7
        self.enableDDC = try container.decodeIfPresent(Bool.self, forKey: .enableDDC) ?? true
        self.hotwords = try container.decodeIfPresent([String].self, forKey: .hotwords) ?? ["Claude Code", "openclaw"]
    }
}
