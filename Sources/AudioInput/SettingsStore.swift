import Foundation

final class SettingsStore {
    private(set) var settings: AppSettings
    private let fileURL: URL

    init(config: AppConfig) {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support")
        let dir = appSupport.appendingPathComponent("AudioInput", isDirectory: true)
        self.fileURL = dir.appendingPathComponent("settings.json")

        if let loaded = Self.load(from: fileURL) {
            self.settings = loaded
        } else {
            let env = Environment.loadMerged()
            self.settings = AppSettings.default(fallbackMaxRecordSeconds: config.defaultMaxRecordSeconds, env: env)
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            try? save()
        }
    }

    func update(_ mutate: (inout AppSettings) -> Void) {
        mutate(&settings)
        do {
            try save()
        } catch {
            AppLogger.log.error("Failed to save settings: \(error.localizedDescription)")
        }
    }

    private func save() throws {
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(settings)
        try data.write(to: fileURL, options: .atomic)
    }

    private static func load(from url: URL) -> AppSettings? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(AppSettings.self, from: data)
    }
}
