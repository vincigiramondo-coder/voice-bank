import Foundation

enum VoiceBankLanguageMode: String, CaseIterable {
    case system
    case english
    case chinese

    var title: String {
        switch self {
        case .system:
            return VoiceBankText.pick("System", "跟随系统")
        case .english:
            return "English"
        case .chinese:
            return "中文"
        }
    }
}

enum VoiceBankText {
    private static let languageModeKey = "voicebank.languageMode"

    static var languageMode: VoiceBankLanguageMode {
        get {
            let value = UserDefaults.standard.string(forKey: languageModeKey) ?? VoiceBankLanguageMode.system.rawValue
            return VoiceBankLanguageMode(rawValue: value) ?? .system
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: languageModeKey)
        }
    }

    static var useChinese: Bool {
        switch languageMode {
        case .system:
            break
        case .english:
            return false
        case .chinese:
            return true
        }
        return Locale.preferredLanguages.first?.lowercased().hasPrefix("zh") == true
    }

    static func pick(_ english: String, _ chinese: String) -> String {
        useChinese ? chinese : english
    }
}
