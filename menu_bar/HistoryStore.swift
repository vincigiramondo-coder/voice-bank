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

    func clearAll() throws {
        let manager = FileManager.default
        if manager.fileExists(atPath: historyFolderURL.path) {
            try manager.removeItem(at: historyFolderURL)
        }
        try manager.createDirectory(
            at: historyFolderURL,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
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
}
