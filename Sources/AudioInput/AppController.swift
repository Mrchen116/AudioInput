import AppKit
import Foundation

@MainActor
final class AppController {
    private let config: AppConfig
    private let settingsStore: SettingsStore
    private let recorder: AudioRecorder
    private let asrClient: ASRClient
    private let inserter: TextInserter
    private let monitor: HotkeyMonitor
    private let statusBar: StatusBarController
    private let notifier: Notifier
    private let structuredLogger: StructuredLogger

    private var state: InputState = .idle {
        didSet { statusBar.update(state: state) }
    }

    private var cancelCurrentRecording = false
    private var timeoutTimer: Timer?
    private var settingsWindowController: SettingsWindowController?
    private var lastRecordStopAt: Date = .distantPast

    init(
        config: AppConfig,
        settingsStore: SettingsStore,
        recorder: AudioRecorder,
        asrClient: ASRClient,
        inserter: TextInserter,
        monitor: HotkeyMonitor,
        statusBar: StatusBarController,
        notifier: Notifier,
        structuredLogger: StructuredLogger
    ) {
        self.config = config
        self.settingsStore = settingsStore
        self.recorder = recorder
        self.asrClient = asrClient
        self.inserter = inserter
        self.monitor = monitor
        self.statusBar = statusBar
        self.notifier = notifier
        self.structuredLogger = structuredLogger

        wireEvents()
    }

    func start() {
        AudioRecorder.cleanupStaleTemporaryFiles()
        state = .idle
        statusBar.onQuit = { NSApplication.shared.terminate(nil) }
        statusBar.onOpenSettings = { [weak self] in self?.openSettings() }
        statusBar.onSelfCheck = { [weak self] in self?.runSelfCheck() }

        applySettingsRuntimeEffects()

        notifier.requestAuthorization()
        PermissionHelper.requestMicrophoneAccess()

        if !PermissionHelper.requestAccessibilityTrust() {
            notifier.notify(
                title: "Audio Input",
                body: "Please enable Accessibility for AudioInput, then restart app."
            )
        }

        if !PermissionHelper.requestInputMonitoringAccess() {
            notifier.notify(
                title: "Audio Input",
                body: "Please enable Input Monitoring for AudioInput, then restart app."
            )
        }

        let monitorStarted = monitor.start()
        if !monitorStarted || !PermissionHelper.hasInputMonitoringAccess() {
            state = .error("Hotkey monitor unavailable")
            notifier.notify(
                title: "Audio Input",
                body: "Hotkeys unavailable. Grant Input Monitoring and relaunch."
            )
            log(.error, event: "hotkey_monitor_unavailable", message: "Failed to start hotkey monitor")
            return
        }

        notifier.notify(title: "Audio Input", body: "Ready: hold \(settingsStore.settings.hotkeySide.rawValue) Command to talk")
        log(.info, event: "app_started", message: "AudioInput started")
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

        let debounceWindow = 0.2
        if Date().timeIntervalSince(lastRecordStopAt) < debounceWindow {
            return
        }

        if settingsStore.settings.appID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
            settingsStore.settings.accessToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            notifier.notify(title: "Audio Input", body: "Please set APP_ID and ACCESS_TOKEN in Settings")
            log(.warning, event: "missing_credentials", message: "Cannot start recording because credentials are empty")
            return
        }

        do {
            try recorder.start()
            cancelCurrentRecording = false
            state = .recording(startAt: Date())
            notifier.notify(title: "Audio Input", body: "Recording...")

            let timeout = TimeInterval(max(30, settingsStore.settings.maxRecordSeconds))
            timeoutTimer = Timer.scheduledTimer(withTimeInterval: timeout, repeats: false) { [weak self] _ in
                Task { @MainActor in self?.finishRecording(timeout: true) }
            }
            log(.info, event: "recording_started", message: "Recording started")
        } catch {
            state = .error(error.localizedDescription)
            notifier.notify(title: "Audio Input", body: "Recording failed: \(error.localizedDescription)")
            log(.error, event: "recording_failed", message: error.localizedDescription)
            state = .idle
        }
    }

    private func cancelRecordingByEsc() {
        guard case .recording = state else { return }
        cancelCurrentRecording = true
        recorder.cancel()
        clearTimeout()
        lastRecordStopAt = Date()
        state = .idle
        notifier.notify(title: "Audio Input", body: "Recording canceled")
        log(.info, event: "recording_canceled", message: "Recording canceled by ESC")
    }

    private func finishRecording(timeout: Bool = false) {
        guard case .recording = state else { return }

        if cancelCurrentRecording {
            cancelCurrentRecording = false
            clearTimeout()
            lastRecordStopAt = Date()
            state = .idle
            return
        }

        do {
            let recorded = try recorder.stop()
            clearTimeout()
            lastRecordStopAt = Date()

            if recorded.durationMS < config.minRecordMS {
                try? FileManager.default.removeItem(at: recorded.url)
                state = .idle
                notifier.notify(title: "Audio Input", body: "Ignored: recording too short")
                log(.info, event: "recording_too_short", message: "duration_ms=\(recorded.durationMS)")
                return
            }

            if timeout {
                notifier.notify(title: "Audio Input", body: "Reached \(settingsStore.settings.maxRecordSeconds)s limit, transcribing")
            }

            state = .transcribing
            transcribeAndInsert(recorded: recorded)
        } catch {
            state = .error(error.localizedDescription)
            notifier.notify(title: "Audio Input", body: "Stop recording failed: \(error.localizedDescription)")
            log(.error, event: "recording_stop_failed", message: error.localizedDescription)
            state = .idle
        }
    }

    private func transcribeAndInsert(recorded: RecordedAudio) {
        let snapshot = settingsStore.settings
        let asrClient = self.asrClient
        let inserter = self.inserter
        let language = self.config.asrLanguage

        Task.detached {
            defer { try? FileManager.default.removeItem(at: recorded.url) }

            do {
                let audioData = try Data(contentsOf: recorded.url)
                let text = try await asrClient.recognize(
                    wavData: audioData,
                    language: language,
                    appID: snapshot.appID,
                    accessToken: snapshot.accessToken
                )

                await MainActor.run {
                    self.state = .inserting
                    inserter.paste(text, keepClipboard: snapshot.keepTranscriptionInClipboard)
                    self.notifier.notify(title: "Audio Input", body: "Inserted \(text.count) chars")
                    self.log(.info, event: "inserted", message: "chars=\(text.count)")
                    self.state = .idle
                }
            } catch {
                await MainActor.run {
                    self.state = .error(error.localizedDescription)
                    self.notifier.notify(title: "Audio Input", body: "Transcription failed: \(error.localizedDescription)")
                    self.log(.error, event: "transcription_failed", message: error.localizedDescription)
                    self.state = .idle
                }
            }
        }
    }

    private func clearTimeout() {
        timeoutTimer?.invalidate()
        timeoutTimer = nil
    }

    private func openSettings() {
        if settingsWindowController == nil {
            settingsWindowController = SettingsWindowController(
                getSettings: { [weak self] in
                    self?.settingsStore.settings ?? AppSettings.default(fallbackMaxRecordSeconds: 180, env: [:])
                },
                onSave: { [weak self] newSettings in
                    self?.saveSettings(newSettings)
                }
            )
        }

        settingsWindowController?.show()
    }

    private func saveSettings(_ newSettings: AppSettings) {
        settingsStore.update { current in
            current = newSettings
        }
        applySettingsRuntimeEffects()
        structuredLogger.pruneNow()
        notifier.notify(title: "Audio Input", body: "Settings saved")
        log(.info, event: "settings_saved", message: "Settings updated")
    }

    private func applySettingsRuntimeEffects() {
        let settings = settingsStore.settings
        monitor.setHotkeySide(settings.hotkeySide)
        LaunchAtLoginManager.apply(enabled: settings.launchAtLogin)
    }

    private func runSelfCheck() {
        let s = settingsStore.settings
        let checks: [String] = [
            "Accessibility: \(PermissionHelper.hasAccessibilityTrust() ? "OK" : "Missing")",
            "Input Monitoring: \(PermissionHelper.hasInputMonitoringAccess() ? "OK" : "Missing")",
            "APP_ID: \(s.appID.isEmpty ? "Missing" : "OK")",
            "ACCESS_TOKEN: \(s.accessToken.isEmpty ? "Missing" : "OK")",
            "Hotkey: \(s.hotkeySide.rawValue)",
            "MaxRecord: \(s.maxRecordSeconds)s",
            "Clipboard: \(s.keepTranscriptionInClipboard ? "Keep" : "Restore")",
            "LogRetention: \(s.logRetentionDays)d",
        ]

        let body = checks.joined(separator: " | ")
        notifier.notify(title: "Audio Input Self Check", body: body)
        log(.info, event: "self_check", message: body)
    }

    private func log(_ level: LogLevel, event: String, message: String) {
        structuredLogger.log(level, event: event, message: message)
        switch level {
        case .info:
            AppLogger.log.info("\(event): \(message)")
        case .warning:
            AppLogger.log.warning("\(event): \(message)")
        case .error:
            AppLogger.log.error("\(event): \(message)")
        }
    }
}
