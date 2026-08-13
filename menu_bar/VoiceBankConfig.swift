import Foundation
import Darwin

enum VoiceBankConfig {
    private static let defaultEndpoint = "http://127.0.0.1:8767/transcribe"
    private static let defaultHealthURL = "http://127.0.0.1:8767/healthz"

    static var projectDirectory: String {
        configuredValue(environmentKey: "VOICEBANK_PROJECT_DIR", infoKey: "VoiceBankProjectDirectory")
            ?? FileManager.default.currentDirectoryPath
    }

    static var endpoint: String {
        configuredValue(environmentKey: "VOICE_INPUT_SERVER_URL", infoKey: "VoiceBankServerURL")
            ?? defaultEndpoint
    }

    static var healthURL: URL {
        let value = configuredValue(environmentKey: "VOICEBANK_HEALTH_URL", infoKey: "VoiceBankHealthURL")
            ?? defaultHealthURL
        return URL(string: value) ?? URL(string: defaultHealthURL)!
    }

    static var endpointDisplay: String {
        URL(string: endpoint)?.hostAndPort ?? endpoint
    }

    static var historyDirectoryURL: URL {
        if let configured = ProcessInfo.processInfo.environment["VOICE_BANK_LOCAL_HISTORY_DIR"]?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !configured.isEmpty {
            return URL(fileURLWithPath: NSString(string: configured).expandingTildeInPath, isDirectory: true)
        }
        return FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Documents/Voice Bank/History", isDirectory: true)
    }

    static var serverToken: String? {
        if let value = ProcessInfo.processInfo.environment["VOICE_INPUT_SERVER_TOKEN"]?.trimmingCharacters(in: .whitespacesAndNewlines),
           !value.isEmpty {
            return value
        }

        let tokenURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/Voice Bank/server-token")
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: tokenURL.path),
              let ownerID = attributes[.ownerAccountID] as? NSNumber,
              ownerID.uint32Value == getuid(),
              let permissions = attributes[.posixPermissions] as? NSNumber,
              permissions.intValue & 0o077 == 0,
              let contents = try? String(contentsOf: tokenURL, encoding: .utf8) else {
            return nil
        }
        let trimmed = contents.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func configuredValue(environmentKey: String, infoKey: String) -> String? {
        if let value = ProcessInfo.processInfo.environment[environmentKey]?.trimmingCharacters(in: .whitespacesAndNewlines),
           !value.isEmpty {
            return value
        }
        if let value = Bundle.main.object(forInfoDictionaryKey: infoKey) as? String {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }
        return nil
    }
}

private extension URL {
    var hostAndPort: String {
        guard let host else {
            return absoluteString
        }
        return port.map { "\(host):\($0)" } ?? host
    }
}
