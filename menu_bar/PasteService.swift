import AppKit
import ApplicationServices
import CoreGraphics
import Foundation

enum PasteResult {
    case pasted
    case copiedFocusChanged
    case copiedNeedsAccessibility
    case copiedPasteEventFailed
    case missingText

    var status: VoiceBankStatus {
        switch self {
        case .pasted:
            return .pasted
        case .copiedFocusChanged:
            return .copiedFocusChanged
        case .copiedNeedsAccessibility:
            return .copiedNeedsAccessibility
        case .copiedPasteEventFailed:
            return .copiedPasteEventFailed
        case .missingText:
            return .missingText
        }
    }
}

final class PasteService {
    private let permissions: PermissionsService
    private let appendLog: (String) -> Void

    init(permissions: PermissionsService, appendLog: @escaping (String) -> Void) {
        self.permissions = permissions
        self.appendLog = appendLog
    }

    func pasteRecognizedText(
        from output: String,
        originatingProcessIdentifier: pid_t?,
        onAccessibilityMissing: () -> Void
    ) -> PasteResult {
        guard let text = recognizedText(from: output), !text.isEmpty else {
            appendLog("paste missing_text outputChars=\(output.count)")
            return .missingText
        }

        let copied = writeClipboard(text)
        appendLog("paste textChars=\(text.count) clipboard=\(copied) axTrusted=\(permissions.isAccessibilityTrusted())")
        guard copied else {
            return .copiedPasteEventFailed
        }

        if let originatingProcessIdentifier,
           NSWorkspace.shared.frontmostApplication?.processIdentifier != originatingProcessIdentifier {
            return .copiedFocusChanged
        }

        guard permissions.isAccessibilityTrusted() else {
            onAccessibilityMissing()
            return .copiedNeedsAccessibility
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            self?.sendCommandV(originatingProcessIdentifier: originatingProcessIdentifier)
        }
        return .pasted
    }

    func recognizedText(from output: String) -> String? {
        let marker = "输出文本"
        for line in output.split(separator: "\n").reversed() {
            guard line.contains(marker), let colonRange = line.range(of: ":") else {
                continue
            }
            let value = String(line[colonRange.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !value.isEmpty {
                return value
            }
        }
        return nil
    }

    private func writeClipboard(_ text: String) -> Bool {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        if pasteboard.setString(text, forType: .string) {
            return true
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/pbcopy")
        let pipe = Pipe()
        process.standardInput = pipe
        do {
            try process.run()
            pipe.fileHandleForWriting.write(Data(text.utf8))
            pipe.fileHandleForWriting.closeFile()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            appendLog("clipboard fallback failed error=\(error.localizedDescription)")
            return false
        }
    }

    private func sendCommandV(originatingProcessIdentifier: pid_t?) {
        if let originatingProcessIdentifier,
           NSWorkspace.shared.frontmostApplication?.processIdentifier != originatingProcessIdentifier {
            appendLog("paste skipped focus_changed")
            return
        }
        guard let source = CGEventSource(stateID: .hidSystemState) else {
            appendLog("paste eventSource failed")
            return
        }
        let keyCodeV: CGKeyCode = 9
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCodeV, keyDown: true)
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCodeV, keyDown: false)
        keyDown?.flags = .maskCommand
        keyUp?.flags = .maskCommand
        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
        appendLog("paste command_v posted")
    }
}
