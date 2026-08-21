import Foundation

@main
struct NativeHistorySmoke {
    static func main() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("voicebank-native-history-smoke-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let store = HistoryStore(indexURL: root.appendingPathComponent("index.jsonl"))
        let response: [String: Any] = [
            "raw": "native raw",
            "polished": "native polished",
            "duration": 1.25,
            "timings": ["total_seconds": 1.5],
            "polish_mode": "smoke",
            "polish_guarded": false,
            "memory": ["id": "native-smoke"]
        ]

        try store.append(
            result: response,
            outputText: "native polished",
            endpoint: "http://127.0.0.1:8767/transcribe"
        )

        let entries = store.loadEntries()
        precondition(entries.count == 1)
        precondition(entries[0].text == "native polished")
        precondition(entries[0].raw == "native raw")
        precondition(FileManager.default.fileExists(atPath: store.indexURL.path))
        print("NativeHistorySmoke OK")
    }
}
