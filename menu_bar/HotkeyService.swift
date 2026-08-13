import AppKit
import CoreGraphics
import Foundation

struct HotkeyServiceCallbacks {
    let toggleRecording: () -> Void
    let cancelRecording: () -> Void
    let updateHotkeyStatus: (String) -> Void
    let setStatus: (VoiceBankStatus) -> Void
    let setHotkeyMenuTitle: (String) -> Void
}

final class HotkeyService {
    private let permissions: PermissionsService
    private let callbacks: HotkeyServiceCallbacks

    private var rightOptionEventTap: CFMachPort?
    private var rightOptionRunLoopSource: CFRunLoopSource?
    private var globalFlagsMonitor: Any?
    private var globalKeyMonitor: Any?
    private var localFlagsMonitor: Any?
    private var localKeyMonitor: Any?
    private var rightOptionDown = false
    private var lastRightOptionToggle = Date.distantPast

    init(permissions: PermissionsService, callbacks: HotkeyServiceCallbacks) {
        self.permissions = permissions
        self.callbacks = callbacks
    }

    func install() {
        guard rightOptionEventTap == nil else {
            return
        }

        if !permissions.isInputMonitoringAllowed() {
            callbacks.setHotkeyMenuTitle(VoiceBankText.pick("Hotkey: Right Option (needs permission)", "热键：右 Option（需要权限）"))
            callbacks.updateHotkeyStatus(VoiceBankText.pick("Input Monitoring permission required", "需要输入监控权限"))
            callbacks.setStatus(.allowInputMonitoring)
            _ = permissions.requestInputMonitoring()
        }

        let flagsMask = CGEventMask(1) << CGEventType.flagsChanged.rawValue
        let keyMask = CGEventMask(1) << CGEventType.keyDown.rawValue
        let eventMask = flagsMask | keyMask
        guard let eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: eventMask,
            callback: { _, type, event, userInfo in
                guard let userInfo else {
                    return Unmanaged.passUnretained(event)
                }

                let service = Unmanaged<HotkeyService>.fromOpaque(userInfo).takeUnretainedValue()
                service.handleEventTap(type: type, event: event)
                return Unmanaged.passUnretained(event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            callbacks.setHotkeyMenuTitle(VoiceBankText.pick("Hotkey: Right Option (not active)", "热键：右 Option（未启用）"))
            installNSEventFallback()
            callbacks.updateHotkeyStatus(VoiceBankText.pick("Using fallback hotkey listener", "正在使用备用热键监听"))
            callbacks.setStatus(.hotkeyPermissionNeeded)
            return
        }

        rightOptionEventTap = eventTap
        rightOptionRunLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        if let rightOptionRunLoopSource {
            CFRunLoopAddSource(CFRunLoopGetMain(), rightOptionRunLoopSource, .commonModes)
            CGEvent.tapEnable(tap: eventTap, enable: true)
            callbacks.setHotkeyMenuTitle(VoiceBankText.pick("Hotkey: Right Option", "热键：右 Option"))
            callbacks.updateHotkeyStatus(VoiceBankText.pick("Right Option is listening", "右 Option 正在监听"))
        }

        installNSEventFallback()
    }

    func remove() {
        if let rightOptionRunLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), rightOptionRunLoopSource, .commonModes)
            self.rightOptionRunLoopSource = nil
        }
        if let rightOptionEventTap {
            CGEvent.tapEnable(tap: rightOptionEventTap, enable: false)
            self.rightOptionEventTap = nil
        }
        for monitor in [globalFlagsMonitor, globalKeyMonitor, localFlagsMonitor, localKeyMonitor].compactMap({ $0 }) {
            NSEvent.removeMonitor(monitor)
        }
        globalFlagsMonitor = nil
        globalKeyMonitor = nil
        localFlagsMonitor = nil
        localKeyMonitor = nil
    }

    private func handleEventTap(type: CGEventType, event: CGEvent) {
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)

        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            DispatchQueue.main.async { [weak self] in
                guard let self else {
                    return
                }
                if let rightOptionEventTap = self.rightOptionEventTap {
                    CGEvent.tapEnable(tap: rightOptionEventTap, enable: true)
                }
                self.callbacks.updateHotkeyStatus(VoiceBankText.pick("Right Option listener restored", "右 Option 监听已恢复"))
            }
            return
        }

        if type == .flagsChanged {
            let isRightOption = keyCode == 61
            let isDown = event.flags.contains(.maskAlternate)
            if isRightOption {
                DispatchQueue.main.async { [weak self] in
                    self?.handleRightOption(isDown: isDown)
                }
            }
        } else if type == .keyDown, keyCode == 53 {
            DispatchQueue.main.async { [weak self] in
                self?.callbacks.cancelRecording()
            }
        }
    }

    private func installNSEventFallback() {
        guard globalFlagsMonitor == nil else {
            return
        }

        globalFlagsMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.handleOptionEvent(event)
        }
        globalKeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 {
                DispatchQueue.main.async {
                    self?.callbacks.cancelRecording()
                }
            }
        }
        localFlagsMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.handleOptionEvent(event)
            return event
        }
        localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 {
                self?.callbacks.cancelRecording()
            }
            return event
        }
    }

    private func handleOptionEvent(_ event: NSEvent) {
        guard event.keyCode == 61 else {
            return
        }
        handleRightOption(isDown: event.modifierFlags.contains(.option))
    }

    private func handleRightOption(isDown: Bool) {
        if isDown, !rightOptionDown {
            rightOptionDown = true
        } else if !isDown, rightOptionDown {
            rightOptionDown = false
            let now = Date()
            guard now.timeIntervalSince(lastRightOptionToggle) > 0.35 else {
                return
            }
            lastRightOptionToggle = now
            callbacks.toggleRecording()
        }
    }
}
