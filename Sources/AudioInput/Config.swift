import Foundation

struct AppConfig {
    let resourceID: String
    let asrURL: URL
    let asrLanguage: String
    let defaultMaxRecordSeconds: Int
    let minRecordMS: Int

    static func load() throws -> AppConfig {
        let env = Environment.loadMerged()

        let resourceID = env["RESOURCE_ID"] ?? "volc.bigasr.auc_turbo"
        let asrURLString = env["ASR_URL"] ?? "https://openspeech.bytedance.com/api/v3/auc/bigmodel/recognize/flash"
        guard let asrURL = URL(string: asrURLString) else {
            throw ConfigError.invalid("ASR_URL")
        }

        let asrLanguage = env["ASR_LANGUAGE"] ?? "auto"
        let maxRecordSeconds = Int(env["MAX_RECORD_SECONDS"] ?? "180") ?? 180
        let minRecordMS = Int(env["MIN_RECORD_MS"] ?? "180") ?? 180

        return AppConfig(
            resourceID: resourceID,
            asrURL: asrURL,
            asrLanguage: asrLanguage,
            defaultMaxRecordSeconds: max(1, maxRecordSeconds),
            minRecordMS: max(50, minRecordMS)
        )
    }
}

enum ConfigError: Error, LocalizedError {
    case invalid(String)

    var errorDescription: String? {
        switch self {
        case .invalid(let key):
            return "Invalid config: \(key)"
        }
    }
}
