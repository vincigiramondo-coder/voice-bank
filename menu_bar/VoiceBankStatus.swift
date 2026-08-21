import AppKit

enum VoiceBankStatus: Equatable {
    case ready
    case idle
    case recording
    case processing
    case stillProcessing
    case alreadyRecording
    case canceled
    case pasted
    case copiedNeedsAccessibility
    case copiedPasteEventFailed
    case missingText
    case failed(String)
    case launchFailed(String)
    case timedOut
    case testingMini
    case miniOK
    case miniReachable
    case miniFailed(String)
    case miniFailedBadStatus
    case allowAccessibility
    case allowInputMonitoring
    case hotkeyPermissionNeeded

    var text: String {
        switch self {
        case .ready:
            return VoiceBankText.pick("Ready", "就绪")
        case .idle:
            return VoiceBankText.pick("Idle", "空闲")
        case .recording:
            return VoiceBankText.pick("Recording", "录音中")
        case .processing:
            return VoiceBankText.pick("Processing", "识别中")
        case .stillProcessing:
            return VoiceBankText.pick("Still processing", "仍在识别中")
        case .alreadyRecording:
            return VoiceBankText.pick("Already recording", "正在录音")
        case .canceled:
            return VoiceBankText.pick("Canceled", "已取消")
        case .pasted:
            return VoiceBankText.pick("Pasted", "已粘贴")
        case .copiedNeedsAccessibility:
            return VoiceBankText.pick("Copied - allow Accessibility", "已复制，请允许辅助功能权限")
        case .copiedPasteEventFailed:
            return VoiceBankText.pick("Copied - press Command+V", "已复制，请按 Command+V")
        case .missingText:
            return VoiceBankText.pick("Done - no paste text", "已完成，没有可粘贴文本")
        case .failed(let detail):
            return "\(VoiceBankText.pick("Failed", "失败")): \(detail)"
        case .launchFailed(let detail):
            return "\(VoiceBankText.pick("Launch failed", "启动失败")): \(detail)"
        case .timedOut:
            return VoiceBankText.pick("Timed out", "识别超时")
        case .testingMini:
            return VoiceBankText.pick("Testing Mini", "正在测试 Mini")
        case .miniOK:
            return VoiceBankText.pick("Mini OK", "Mini 正常")
        case .miniReachable:
            return VoiceBankText.pick("Mini reachable", "Mini 可连接")
        case .miniFailed(let detail):
            return "\(VoiceBankText.pick("Mini failed", "Mini 连接失败")): \(detail)"
        case .miniFailedBadStatus:
            return VoiceBankText.pick("Mini failed: bad status", "Mini 连接失败：状态异常")
        case .allowAccessibility:
            return VoiceBankText.pick("Allow Accessibility", "请允许辅助功能")
        case .allowInputMonitoring:
            return VoiceBankText.pick("Allow Input Monitoring", "请允许输入监控")
        case .hotkeyPermissionNeeded:
            return VoiceBankText.pick("Hotkey permission needed", "需要热键权限")
        }
    }

    var dotColor: NSColor {
        switch self {
        case .recording:
            return NSColor.systemRed
        case .processing, .testingMini:
            return accentColor
        case .failed, .launchFailed, .timedOut, .miniFailed, .miniFailedBadStatus, .hotkeyPermissionNeeded:
            return NSColor.systemOrange
        default:
            return NSColor.systemGreen
        }
    }
}

enum VoiceBankVoiceMenuState {
    case ready
    case recording
    case processing

    var title: String {
        switch self {
        case .ready:
            return VoiceBankText.pick("Start/Stop Recording", "开始/结束录音")
        case .recording:
            return VoiceBankText.pick("Stop Recording", "结束录音")
        case .processing:
            return VoiceBankText.pick("Processing Voice Input", "正在识别")
        }
    }
}
