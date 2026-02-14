import Foundation

enum LogLevel: String {
    case info
    case warning
    case error
}

final class StructuredLogger {
    private let directoryURL: URL
    private let retentionDaysProvider: () -> Int
    private let queue = DispatchQueue(label: "com.audioinput.structured-logger")

    init(retentionDaysProvider: @escaping () -> Int) {
        let base = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library")
        self.directoryURL = base.appendingPathComponent("Logs/AudioInput", isDirectory: true)
        self.retentionDaysProvider = retentionDaysProvider

        queue.async {
            try? FileManager.default.createDirectory(at: self.directoryURL, withIntermediateDirectories: true)
            self.pruneOldLogs()
        }
    }

    func log(_ level: LogLevel, event: String, message: String, metadata: [String: String] = [:]) {
        let line = buildLine(level: level, event: event, message: message, metadata: metadata)
        queue.async {
            self.appendLine(line)
        }
    }

    func pruneNow() {
        queue.async {
            self.pruneOldLogs()
        }
    }

    private func buildLine(level: LogLevel, event: String, message: String, metadata: [String: String]) -> String {
        var payload: [String: Any] = [
            "ts": ISO8601DateFormatter().string(from: Date()),
            "level": level.rawValue,
            "event": event,
            "message": message,
        ]

        if !metadata.isEmpty {
            payload["metadata"] = metadata
        }

        let data = (try? JSONSerialization.data(withJSONObject: payload, options: [])) ?? Data()
        return String(data: data, encoding: .utf8) ?? "{}"
    }

    private func appendLine(_ line: String) {
        let fileURL = dailyLogFileURL()
        let text = line + "\n"

        if FileManager.default.fileExists(atPath: fileURL.path) {
            if let handle = try? FileHandle(forWritingTo: fileURL) {
                defer { try? handle.close() }
                _ = try? handle.seekToEnd()
                try? handle.write(contentsOf: Data(text.utf8))
            }
        } else {
            try? Data(text.utf8).write(to: fileURL, options: .atomic)
        }
    }

    private func dailyLogFileURL() -> URL {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        let filename = "audioinput-\(formatter.string(from: Date())).log"
        return directoryURL.appendingPathComponent(filename)
    }

    private func pruneOldLogs() {
        let days = max(1, retentionDaysProvider())
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date.distantPast
        guard let files = try? FileManager.default.contentsOfDirectory(at: directoryURL, includingPropertiesForKeys: [.contentModificationDateKey]) else {
            return
        }

        for file in files where file.pathExtension == "log" {
            let values = try? file.resourceValues(forKeys: [.contentModificationDateKey])
            let modified = values?.contentModificationDate ?? Date.distantFuture
            if modified < cutoff {
                try? FileManager.default.removeItem(at: file)
            }
        }
    }
}
