import Foundation

protocol ASRClient {
    func recognize(wavData: Data, language: String, appID: String, accessToken: String, enableDDC: Bool, hotwords: [String]) async throws -> String
}

final class VolcASRClient: ASRClient {
    private let config: AppConfig
    private let session: URLSession

    init(config: AppConfig, session: URLSession = .shared) {
        self.config = config
        self.session = session
    }

    func recognize(wavData: Data, language: String, appID: String, accessToken: String, enableDDC: Bool, hotwords: [String]) async throws -> String {
        let cleanAppID = appID.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanToken = accessToken.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanAppID.isEmpty, !cleanToken.isEmpty else {
            throw AppError.missingCredentials
        }

        let maxAttempts = 3
        var attempt = 0
        var lastError: Error?

        while attempt < maxAttempts {
            attempt += 1
            do {
                return try await recognizeOnce(
                    wavData: wavData,
                    language: language,
                    appID: cleanAppID,
                    accessToken: cleanToken,
                    enableDDC: enableDDC,
                    hotwords: hotwords
                )
            } catch {
                lastError = error
                if attempt >= maxAttempts || !shouldRetry(error: error) {
                    throw error
                }
                let delayMS = UInt64(pow(2.0, Double(attempt - 1)) * 300)
                try await Task.sleep(nanoseconds: delayMS * 1_000_000)
            }
        }

        throw lastError ?? AppError.emptyTranscription
    }

    private func recognizeOnce(wavData: Data, language: String, appID: String, accessToken: String, enableDDC: Bool, hotwords: [String]) async throws -> String {
        var request = URLRequest(url: config.asrURL)
        request.httpMethod = "POST"
        request.timeoutInterval = 60
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(appID, forHTTPHeaderField: "X-Api-App-Key")
        request.setValue(accessToken, forHTTPHeaderField: "X-Api-Access-Key")
        request.setValue(config.resourceID, forHTTPHeaderField: "X-Api-Resource-Id")
        request.setValue(UUID().uuidString, forHTTPHeaderField: "X-Api-Request-Id")
        request.setValue("-1", forHTTPHeaderField: "X-Api-Sequence")

        var audio: [String: Any] = [
            "data": wavData.base64EncodedString(),
            "format": "wav",
        ]
        audio["language"] = language

        var requestBody: [String: Any] = [
            "model_name": "bigmodel",
            "enable_itn": true,
            "enable_punc": true,
            "enable_ddc": enableDDC,
        ]

        if !hotwords.isEmpty, let contextJSON = makeHotwordsContextJSON(hotwords: hotwords) {
            requestBody["context"] = contextJSON
        }

        let body: [String: Any] = [
            "user": ["uid": appID],
            "audio": audio,
            "request": requestBody,
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw NSError(domain: "VolcASRClient", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid HTTP response"])
        }

        let apiStatus = http.value(forHTTPHeaderField: "X-Api-Status-Code") ?? ""
        if apiStatus != "20000000" {
            let message = http.value(forHTTPHeaderField: "X-Api-Message") ?? "unknown error"
            let error = NSError(
                domain: "VolcASRClient",
                code: http.statusCode,
                userInfo: [
                    NSLocalizedDescriptionKey: "ASR failed: \(apiStatus) \(message)",
                    "apiStatus": apiStatus,
                ]
            )
            throw error
        }

        guard
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let result = json["result"] as? [String: Any],
            let text = result["text"] as? String,
            !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            throw AppError.emptyTranscription
        }

        return text
    }

    private func shouldRetry(error: Error) -> Bool {
        if let urlError = error as? URLError {
            switch urlError.code {
            case .timedOut, .cannotFindHost, .cannotConnectToHost, .networkConnectionLost, .dnsLookupFailed, .notConnectedToInternet:
                return true
            default:
                return false
            }
        }

        let ns = error as NSError
        if ns.domain == "VolcASRClient" {
            if (500...599).contains(ns.code) {
                return true
            }
            if ns.code == -1 {
                return true
            }
        }

        return false
    }

    private func makeHotwordsContextJSON(hotwords: [String]) -> String? {
        let entries = hotwords.map { ["word": $0] }
        let context: [String: Any] = ["hotwords": entries]
        guard let data = try? JSONSerialization.data(withJSONObject: context, options: []) else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }
}
