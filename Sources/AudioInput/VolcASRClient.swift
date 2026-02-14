import Foundation

protocol ASRClient {
    func recognize(wavData: Data, language: String) async throws -> String
}

final class VolcASRClient: ASRClient {
    private let config: AppConfig
    private let session: URLSession

    init(config: AppConfig, session: URLSession = .shared) {
        self.config = config
        self.session = session
    }

    func recognize(wavData: Data, language: String) async throws -> String {
        var request = URLRequest(url: config.asrURL)
        request.httpMethod = "POST"
        request.timeoutInterval = 60
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(config.appID, forHTTPHeaderField: "X-Api-App-Key")
        request.setValue(config.accessToken, forHTTPHeaderField: "X-Api-Access-Key")
        request.setValue(config.resourceID, forHTTPHeaderField: "X-Api-Resource-Id")
        request.setValue(UUID().uuidString, forHTTPHeaderField: "X-Api-Request-Id")
        request.setValue("-1", forHTTPHeaderField: "X-Api-Sequence")

        var audio: [String: Any] = [
            "data": wavData.base64EncodedString(),
            "format": "wav",
        ]
        audio["language"] = language

        let body: [String: Any] = [
            "user": ["uid": config.appID],
            "audio": audio,
            "request": [
                "model_name": "bigmodel",
                "enable_itn": true,
                "enable_punc": true,
            ],
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw NSError(domain: "VolcASRClient", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid HTTP response"])
        }

        let statusCode = http.value(forHTTPHeaderField: "X-Api-Status-Code") ?? ""
        if statusCode != "20000000" {
            let message = http.value(forHTTPHeaderField: "X-Api-Message") ?? "unknown error"
            throw NSError(domain: "VolcASRClient", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: "ASR failed: \(statusCode) \(message)"])
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
}
