import Foundation

enum Environment {
    static func loadMerged() -> [String: String] {
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
