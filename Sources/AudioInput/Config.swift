import Foundation

struct AppConfig {
    let appID: String
    let accessToken: String
    let resourceID: String
    let asrURL: URL
    let asrLanguage: String
    let maxRecordSeconds: TimeInterval
    let minRecordMS: Int

    static func load() throws -> AppConfig {
        let env = loadMergedEnvironment()

        guard let appID = env["APP_ID"], !appID.isEmpty else {
            throw ConfigError.missing("APP_ID")
        }
        guard let accessToken = env["ACCESS_TOKEN"], !accessToken.isEmpty else {
            throw ConfigError.missing("ACCESS_TOKEN")
        }

        let resourceID = env["RESOURCE_ID"] ?? "volc.bigasr.auc_turbo"
        let asrURLString = env["ASR_URL"] ?? "https://openspeech.bytedance.com/api/v3/auc/bigmodel/recognize/flash"
        guard let asrURL = URL(string: asrURLString) else {
            throw ConfigError.invalid("ASR_URL")
        }

        let asrLanguage = env["ASR_LANGUAGE"] ?? "auto"
        let maxRecordSeconds = TimeInterval(env["MAX_RECORD_SECONDS"] ?? "180") ?? 180
        let minRecordMS = Int(env["MIN_RECORD_MS"] ?? "180") ?? 180

        return AppConfig(
            appID: appID,
            accessToken: accessToken,
            resourceID: resourceID,
            asrURL: asrURL,
            asrLanguage: asrLanguage,
            maxRecordSeconds: max(1, maxRecordSeconds),
            minRecordMS: max(50, minRecordMS)
        )
    }

    private static func loadMergedEnvironment() -> [String: String] {
        var merged = ProcessInfo.processInfo.environment
        let dotEnvPath = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent(".env")

        guard let content = try? String(contentsOf: dotEnvPath, encoding: .utf8) else {
            return merged
        }

        for rawLine in content.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            if line.isEmpty || line.hasPrefix("#") { continue }
            guard let eq = line.firstIndex(of: "=") else { continue }
            let key = String(line[..<eq]).trimmingCharacters(in: .whitespaces)
            var value = String(line[line.index(after: eq)...]).trimmingCharacters(in: .whitespaces)

            if value.hasPrefix("\"") && value.hasSuffix("\"") && value.count >= 2 {
                value.removeFirst()
                value.removeLast()
            }
            if value.hasPrefix("'") && value.hasSuffix("'") && value.count >= 2 {
                value.removeFirst()
                value.removeLast()
            }

            if merged[key] == nil {
                merged[key] = value
            }
        }

        return merged
    }
}

enum ConfigError: Error, LocalizedError {
    case missing(String)
    case invalid(String)

    var errorDescription: String? {
        switch self {
        case .missing(let key):
            return "Missing required config: \(key)"
        case .invalid(let key):
            return "Invalid config: \(key)"
        }
    }
}
