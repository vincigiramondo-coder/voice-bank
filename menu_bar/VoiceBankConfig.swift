import Foundation
import Darwin

enum VoiceBankConfigError: LocalizedError {
    case invalidServerURL

    var errorDescription: String? {
        switch self {
        case .invalidServerURL:
            return VoiceBankText.pick(
                "Use HTTPS, or an HTTP address on localhost, a private LAN, or Tailscale.",
                "请使用 HTTPS，或本机、局域网、Tailscale 中的 HTTP 地址。"
            )
        }
    }
}

enum VoiceBankConfig {
    private static let serverURLDefaultsKey = "voicebank.serverURL"
    private static let defaultEndpoint = "http://127.0.0.1:8767/transcribe"

    static var endpoint: String {
        if let saved = UserDefaults.standard.string(forKey: serverURLDefaultsKey),
           let normalized = normalizedEndpoint(saved) {
            return normalized
        }
        if let value = configuredValue(environmentKey: "VOICE_INPUT_SERVER_URL", infoKey: "VoiceBankServerURL"),
           let normalized = normalizedEndpoint(value) {
            return normalized
        }
        return defaultEndpoint
    }

    static var healthURL: URL {
        if UserDefaults.standard.string(forKey: serverURLDefaultsKey) == nil,
           let explicit = configuredValue(environmentKey: "VOICEBANK_HEALTH_URL", infoKey: "VoiceBankHealthURL"),
           let url = URL(string: explicit) {
            return url
        }
        return derivedHealthURL(from: endpoint)
    }

    static var endpointDisplay: String {
        guard let url = URL(string: endpoint), let host = url.host else {
            return endpoint
        }
        return url.port.map { "\(host):\($0)" } ?? host
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

    static var repositoryURL: URL {
        URL(string: "https://github.com/vincigiramondo-coder/voice-bank")!
    }

    static var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.2.0"
    }

    static func makeURLSession(requestTimeout: TimeInterval = 150, resourceTimeout: TimeInterval = 170) -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = requestTimeout
        configuration.timeoutIntervalForResource = resourceTimeout
        configuration.connectionProxyDictionary = [:]
        configuration.waitsForConnectivity = false
        return URLSession(configuration: configuration)
    }

    static var serverToken: String? {
        if let value = ProcessInfo.processInfo.environment["VOICE_INPUT_SERVER_TOKEN"]?
            .trimmingCharacters(in: .whitespacesAndNewlines),
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

    @discardableResult
    static func saveEndpoint(_ value: String) throws -> String {
        guard let normalized = normalizedEndpoint(value) else {
            throw VoiceBankConfigError.invalidServerURL
        }
        UserDefaults.standard.set(normalized, forKey: serverURLDefaultsKey)
        return normalized
    }

    static func resetEndpoint() {
        UserDefaults.standard.removeObject(forKey: serverURLDefaultsKey)
    }

    private static func normalizedEndpoint(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard var components = URLComponents(string: trimmed),
              let scheme = components.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              let host = components.host,
              scheme == "https" || isAllowedInsecureHost(host) else {
            return nil
        }
        if components.path.isEmpty || components.path == "/" {
            components.path = "/transcribe"
        }
        guard let normalized = components.url?.absoluteString else {
            return nil
        }
        return normalized.hasSuffix("/") ? String(normalized.dropLast()) : normalized
    }

    private static func isAllowedInsecureHost(_ host: String) -> Bool {
        let lower = host.lowercased()
        if lower == "localhost" || lower == "::1" || lower.hasSuffix(".local") || lower.hasSuffix(".ts.net") {
            return true
        }
        if !lower.contains(".") && !lower.contains(":") {
            return true
        }
        if lower.hasPrefix("fc") || lower.hasPrefix("fd") || lower.hasPrefix("fe80:") {
            return true
        }

        let octets = lower.split(separator: ".").compactMap { Int($0) }
        guard octets.count == 4, octets.allSatisfy({ (0...255).contains($0) }) else {
            return false
        }
        if octets[0] == 10 || octets[0] == 127 || octets[0] == 169 && octets[1] == 254 || octets[0] == 192 && octets[1] == 168 {
            return true
        }
        if octets[0] == 172 && (16...31).contains(octets[1]) {
            return true
        }
        return octets[0] == 100 && (64...127).contains(octets[1])
    }

    private static func derivedHealthURL(from endpoint: String) -> URL {
        guard var components = URLComponents(string: endpoint) else {
            return URL(string: "http://127.0.0.1:8767/healthz")!
        }
        components.path = "/healthz"
        components.query = nil
        components.fragment = nil
        return components.url ?? URL(string: "http://127.0.0.1:8767/healthz")!
    }

    private static func configuredValue(environmentKey: String, infoKey: String) -> String? {
        if let value = ProcessInfo.processInfo.environment[environmentKey]?
            .trimmingCharacters(in: .whitespacesAndNewlines),
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
