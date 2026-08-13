import Foundation

enum VoiceBankPreferences {
    private static let saveHistoryKey = "voicebank.saveLocalHistory"
    private static let retentionDaysKey = "voicebank.historyRetentionDays"
    static let retentionOptions = [7, 30, 90, 365]

    static var saveLocalHistory: Bool {
        get {
            UserDefaults.standard.object(forKey: saveHistoryKey) as? Bool ?? false
        }
        set {
            UserDefaults.standard.set(newValue, forKey: saveHistoryKey)
        }
    }

    static var historyRetentionDays: Int {
        get {
            let value = UserDefaults.standard.integer(forKey: retentionDaysKey)
            return retentionOptions.contains(value) ? value : 30
        }
        set {
            let value = retentionOptions.contains(newValue) ? newValue : 30
            UserDefaults.standard.set(value, forKey: retentionDaysKey)
        }
    }
}
