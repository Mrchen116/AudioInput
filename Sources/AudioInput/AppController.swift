import AppKit
import Foundation

@MainActor
final class AppController {
    private let config: AppConfig
    private let recorder: AudioRecorder
    private let asrClient: ASRClient
    private let inserter: TextInserter
    private let monitor: HotkeyMonitor
    private let statusBar: StatusBarController
    private let notifier: Notifier

    private var state: InputState = .idle {
        didSet { statusBar.update(state: state) }
    }

    private var cancelCurrentRecording = false
    private var timeoutTimer: Timer?

    init(
        config: AppConfig,
        recorder: AudioRecorder,
        asrClient: ASRClient,
        inserter: TextInserter,
        monitor: HotkeyMonitor,
        statusBar: StatusBarController,
        notifier: Notifier
    ) {
        self.config = config
        self.recorder = recorder
        self.asrClient = asrClient
        self.inserter = inserter
        self.monitor = monitor
        self.statusBar = statusBar
        self.notifier = notifier

        wireEvents()
    }

    func start() {
        state = .idle
        statusBar.onQuit = { NSApplication.shared.terminate(nil) }
        notifier.requestAuthorization()
        PermissionHelper.requestMicrophoneAccess()

        if !PermissionHelper.requestAccessibilityTrust() {
            notifier.notify(
                title: "Audio Input",
                body: "Please enable Accessibility and Input Monitoring for Terminal, then restart app."
            )
        }

        let monitorStarted = monitor.start()
        if !monitorStarted || !PermissionHelper.hasAccessibilityTrust() {
            state = .error("Hotkey monitor unavailable")
            notifier.notify(
                title: "Audio Input",
                body: "Hotkeys unavailable. Grant Accessibility/Input Monitoring and relaunch."
            )
            return
        }

        notifier.notify(title: "Audio Input", body: "Ready: hold Right Command to talk")
    }

    private func wireEvents() {
        monitor.onRightCommandDown = { [weak self] in
            Task { @MainActor in self?.startRecording() }
        }

        monitor.onRightCommandUp = { [weak self] in
            Task { @MainActor in self?.finishRecording() }
        }

        monitor.onEscDown = { [weak self] in
            Task { @MainActor in self?.cancelRecordingByEsc() }
        }
    }

    private func startRecording() {
        guard case .idle = state else { return }

        do {
            try recorder.start()
            cancelCurrentRecording = false
            state = .recording(startAt: Date())
            notifier.notify(title: "Audio Input", body: "Recording...")
            timeoutTimer = Timer.scheduledTimer(withTimeInterval: config.maxRecordSeconds, repeats: false) { [weak self] _ in
                Task { @MainActor in self?.finishRecording(timeout: true) }
            }
            AppLogger.log.info("Recording started")
        } catch {
            state = .error(error.localizedDescription)
            notifier.notify(title: "Audio Input", body: "Recording failed: \(error.localizedDescription)")
            state = .idle
        }
    }

    private func cancelRecordingByEsc() {
        guard case .recording = state else { return }
        cancelCurrentRecording = true
        recorder.cancel()
        clearTimeout()
        state = .idle
        notifier.notify(title: "Audio Input", body: "Recording canceled")
        AppLogger.log.info("Recording canceled by ESC")
    }

    private func finishRecording(timeout: Bool = false) {
        guard case .recording = state else { return }

        if cancelCurrentRecording {
            cancelCurrentRecording = false
            clearTimeout()
            state = .idle
            return
        }

        do {
            let recorded = try recorder.stop()
            clearTimeout()

            if recorded.durationMS < config.minRecordMS {
                try? FileManager.default.removeItem(at: recorded.url)
                state = .idle
                notifier.notify(title: "Audio Input", body: "Ignored: recording too short")
                return
            }

            if timeout {
                notifier.notify(title: "Audio Input", body: "Reached \(Int(config.maxRecordSeconds))s limit, transcribing")
            }

            state = .transcribing
            transcribeAndInsert(recorded: recorded)
        } catch {
            state = .error(error.localizedDescription)
            notifier.notify(title: "Audio Input", body: "Stop recording failed: \(error.localizedDescription)")
            state = .idle
        }
    }

    private func transcribeAndInsert(recorded: RecordedAudio) {
        let config = self.config
        let asrClient = self.asrClient
        let inserter = self.inserter

        Task.detached {
            do {
                let audioData = try Data(contentsOf: recorded.url)
                let text = try await asrClient.recognize(wavData: audioData, language: config.asrLanguage)

                await MainActor.run {
                    self.state = .inserting
                    inserter.paste(text)
                    self.notifier.notify(title: "Audio Input", body: "Inserted \(text.count) chars")
                    self.state = .idle
                }
            } catch {
                await MainActor.run {
                    self.state = .error(error.localizedDescription)
                    self.notifier.notify(title: "Audio Input", body: "Transcription failed: \(error.localizedDescription)")
                    self.state = .idle
                }
            }

            try? FileManager.default.removeItem(at: recorded.url)
        }
    }

    private func clearTimeout() {
        timeoutTimer?.invalidate()
        timeoutTimer = nil
    }
}
