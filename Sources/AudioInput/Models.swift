import Foundation

struct RecordedAudio {
    let url: URL
    let durationMS: Int
}

enum AppError: Error, LocalizedError {
    case invalidState(String)
    case emptyTranscription
    case missingCredentials

    var errorDescription: String? {
        switch self {
        case .invalidState(let message):
            return message
        case .emptyTranscription:
            return "No transcription text returned"
        case .missingCredentials:
            return "APP_ID or ACCESS_TOKEN is empty. Set them in Settings."
        }
    }
}
