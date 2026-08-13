import AppKit
import ApplicationServices
import CoreGraphics
import Foundation

final class PermissionsService {
    func isAccessibilityTrusted() -> Bool {
        AXIsProcessTrusted()
    }

    func requestAccessibilityIfNeeded() -> Bool {
        let accessibilityOptions = [
            kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true
        ] as CFDictionary
        return AXIsProcessTrustedWithOptions(accessibilityOptions)
    }

    func isInputMonitoringAllowed() -> Bool {
        CGPreflightListenEventAccess()
    }

    func requestInputMonitoring() -> Bool {
        CGRequestListenEventAccess()
    }

    func openInputMonitoringSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent") {
            NSWorkspace.shared.open(url)
        }
    }
}
