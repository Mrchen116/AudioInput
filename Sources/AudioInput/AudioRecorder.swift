import AVFoundation
import Foundation

final class AudioRecorder: NSObject {
    private var recorder: AVAudioRecorder?
    private var startTime: Date?
    private var currentURL: URL?

    func start() throws {
        if recorder?.isRecording == true {
            throw AppError.invalidState("Recorder already running")
        }

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("audioinput-\(UUID().uuidString)")
            .appendingPathExtension("wav")

        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: 16_000,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false,
        ]

        let newRecorder = try AVAudioRecorder(url: url, settings: settings)
        newRecorder.isMeteringEnabled = false
        guard newRecorder.record() else {
            throw AppError.invalidState("Failed to start audio recording")
        }

        recorder = newRecorder
        startTime = Date()
        currentURL = url
    }

    func stop() throws -> RecordedAudio {
        guard let recorder, let startTime, let currentURL else {
            throw AppError.invalidState("Recorder is not running")
        }

        recorder.stop()
        self.recorder = nil
        self.startTime = nil
        self.currentURL = nil

        let ms = Int(Date().timeIntervalSince(startTime) * 1000)
        return RecordedAudio(url: currentURL, durationMS: max(0, ms))
    }

    func cancel() {
        recorder?.stop()
        recorder = nil
        startTime = nil

        if let currentURL {
            try? FileManager.default.removeItem(at: currentURL)
        }

        self.currentURL = nil
    }
}
