import Foundation

struct HistoryEntry {
    let id: String
    let createdAt: String
    let date: String
    let time: String
    let text: String
    let raw: String
    let textChars: Int
}

struct HistoryStats {
    let entryCount: Int
    let todayChars: Int
    let totalChars: Int
}

struct HistoryDayGroup {
    let date: String
    let title: String
    let entries: [HistoryEntry]
}

struct HistoryStore {
    let indexURL: URL

    init(indexURL: URL = VoiceBankConfig.historyDirectoryURL.appendingPathComponent("index.jsonl")) {
        self.indexURL = indexURL
    }

    var historyFolderURL: URL {
        indexURL.deletingLastPathComponent()
    }

    func append(result: [String: Any], outputText: String, endpoint: String) throws {
        let manager = FileManager.default
        let dailyDirectory = historyFolderURL.appendingPathComponent("daily", isDirectory: true)
        try manager.createDirectory(
            at: historyFolderURL,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        try manager.createDirectory(
            at: dailyDirectory,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        try manager.setAttributes([.posixPermissions: 0o700], ofItemAtPath: historyFolderURL.path)
        try manager.setAttributes([.posixPermissions: 0o700], ofItemAtPath: dailyDirectory.path)

        let now = Date()
        let rawText = result["raw"] as? String ?? ""
        let polishedText = result["polished"] as? String ?? outputText
        let memory = result["memory"] as? [String: Any]
        let entry: [String: Any] = [
            "id": "air-\(Self.compactTimestampFormatter.string(from: now))-\(UUID().uuidString.prefix(8).lowercased())",
            "created_at": Self.isoFormatter.string(from: now),
            "date": Self.dayFormatter.string(from: now),
            "time": Self.timeFormatter.string(from: now),
            "source": "voice_bank_native",
            "server_url": endpoint,
            "server_memory_id": memory?["id"] ?? NSNull(),
            "raw": rawText,
            "polished": polishedText,
            "text": outputText,
            "raw_chars": rawText.count,
            "text_chars": outputText.count,
            "duration": result["duration"] ?? NSNull(),
            "timings": result["timings"] ?? [:],
            "polish_mode": result["polish_mode"] ?? NSNull(),
            "polish_guarded": result["polish_guarded"] ?? NSNull()
        ]

        let jsonData = try JSONSerialization.data(withJSONObject: entry, options: [.sortedKeys])
        var indexLine = jsonData
        indexLine.append(Data("\n".utf8))
        if !manager.fileExists(atPath: indexURL.path) {
            manager.createFile(atPath: indexURL.path, contents: nil, attributes: [.posixPermissions: 0o600])
        }
        let indexHandle = try FileHandle(forWritingTo: indexURL)
        try indexHandle.seekToEnd()
        try indexHandle.write(contentsOf: indexLine)
        try indexHandle.close()
        try manager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: indexURL.path)

        let dailyURL = dailyDirectory.appendingPathComponent("\(Self.dayFormatter.string(from: now)).md")
        var dailyText = "\n## \(Self.timeFormatter.string(from: now)) · \(outputText.count) 字\n\n\(outputText.trimmingCharacters(in: .whitespacesAndNewlines))\n"
        if !rawText.isEmpty, rawText != outputText {
            dailyText += "\n原始转写：\n\n\(rawText.trimmingCharacters(in: .whitespacesAndNewlines))\n"
        }
        let dailyData = Data(dailyText.utf8)
        if !manager.fileExists(atPath: dailyURL.path) {
            manager.createFile(atPath: dailyURL.path, contents: nil, attributes: [.posixPermissions: 0o600])
        }
        let dailyHandle = try FileHandle(forWritingTo: dailyURL)
        try dailyHandle.seekToEnd()
        try dailyHandle.write(contentsOf: dailyData)
        try dailyHandle.close()
        try manager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: dailyURL.path)
    }

    func loadEntries() -> [HistoryEntry] {
        guard let content = try? String(contentsOf: indexURL, encoding: .utf8) else {
            return []
        }
        let entries = content.split(separator: "\n").compactMap { line -> HistoryEntry? in
            parseLine(String(line))
        }
        return entries.sorted { $0.createdAt > $1.createdAt }
    }

    func stats(for entries: [HistoryEntry]? = nil, today: Date = Date()) -> HistoryStats {
        let loadedEntries = entries ?? loadEntries()
        let todayString = Self.dayFormatter.string(from: today)
        let todayChars = loadedEntries
            .filter { $0.date == todayString }
            .reduce(0) { $0 + $1.textChars }
        let totalChars = loadedEntries.reduce(0) { $0 + $1.textChars }
        return HistoryStats(
            entryCount: loadedEntries.count,
            todayChars: todayChars,
            totalChars: totalChars
        )
    }

    func dayGroups(for entries: [HistoryEntry]? = nil, today: Date = Date()) -> [HistoryDayGroup] {
        let loadedEntries = entries ?? loadEntries()
        let grouped = Dictionary(grouping: loadedEntries) { $0.date }
        return grouped.keys.sorted(by: >).map { date in
            let groupEntries = (grouped[date] ?? []).sorted { $0.createdAt > $1.createdAt }
            return HistoryDayGroup(
                date: date,
                title: dayTitle(for: date, today: today),
                entries: groupEntries
            )
        }
    }

    private func parseLine(_ line: String) -> HistoryEntry? {
        guard let data = line.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        let text = (object["text"] as? String) ?? (object["polished"] as? String) ?? ""
        guard !text.isEmpty else {
            return nil
        }

        return HistoryEntry(
            id: (object["id"] as? String) ?? "",
            createdAt: (object["created_at"] as? String) ?? "",
            date: (object["date"] as? String) ?? "",
            time: (object["time"] as? String) ?? "",
            text: text,
            raw: (object["raw"] as? String) ?? "",
            textChars: (object["text_chars"] as? Int) ?? text.count
        )
    }

    private func dayTitle(for date: String, today: Date) -> String {
        let todayStart = Calendar.current.startOfDay(for: today)
        let todayString = Self.dayFormatter.string(from: todayStart)
        if date == todayString {
            return "Today"
        }

        if let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: todayStart),
           date == Self.dayFormatter.string(from: yesterday) {
            return "Yesterday"
        }

        return date
    }

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()

    private static let compactTimestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter
    }()

    private static let isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()
}
