import AppKit
import ApplicationServices
import CoreGraphics
import Foundation

final class DashboardWindowController: NSWindowController {
    let statusLabel = makeLabel(VoiceBankStatus.ready.text, size: 15, weight: .medium, color: mutedTextColor)
    let statusDot = RoundedView(fillColor: NSColor.systemGreen, strokeColor: .clear, radius: 5)
    let hotkeyStatusLabel = makeLabel(VoiceBankText.pick("Right Option is listening", "右 Option 正在监听"), size: 13, color: mutedTextColor)
    let wordsTodayLabel = makeLabel("0", size: 34, weight: .bold)
    let totalWordsLabel = makeLabel("0", size: 34, weight: .bold)
    let sidebarHost = NSView()
    let contentHost = NSView()
    let historyStore = HistoryStore()
    var selectedPage: DashboardPage = .home
    var historyFolderURL: URL {
        historyStore.historyFolderURL
    }

    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1040, height: 720),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Voice Bank"
        window.minSize = NSSize(width: 880, height: 600)
        super.init(window: window)
        window.contentView = buildRootView()
        showPage(.home)
        window.center()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func show() {
        refreshStatsFromHistory()
        if selectedPage == .history {
            showPage(.history)
        }
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func updateStatus(_ status: VoiceBankStatus) {
        statusLabel.stringValue = status.text
        statusDot.fillColor = status.dotColor
        statusDot.needsLayout = true
    }

    func updateHotkeyStatus(_ status: String) {
        hotkeyStatusLabel.stringValue = status
    }

    func addWords(_ count: Int) {
        guard count > 0 else {
            return
        }
        let today = (Int(wordsTodayLabel.stringValue) ?? 0) + count
        let total = (Int(totalWordsLabel.stringValue) ?? 0) + count
        wordsTodayLabel.stringValue = "\(today)"
        totalWordsLabel.stringValue = "\(total)"
    }

}

private enum RecordingOverlayState {
    case recording
    case processing
    case done
    case canceled
    case failed

    var labelText: String {
        switch self {
        case .recording:
            return VoiceBankText.pick("Recording", "录音中")
        case .processing:
            return VoiceBankText.pick("Recognizing", "识别中")
        case .done:
            return VoiceBankText.pick("Done", "已完成")
        case .canceled:
            return VoiceBankText.pick("Canceled", "已取消")
        case .failed:
            return VoiceBankText.pick("Failed", "失败")
        }
    }
}

final class RecordingOverlayController {
    private let panel: NSPanel
    private let label = makeLabel(RecordingOverlayState.recording.labelText, size: 20, weight: .semibold, alignment: .center)
    private let icon = makeSymbol("mic.fill", pointSize: 24, color: accentColor)
    private let indicatorHost = NSView()
    private let barsStack = NSStackView()
    private let spinner = NSProgressIndicator()
    private var barViews: [RoundedView] = []
    private var barHeightConstraints: [NSLayoutConstraint] = []
    private var recentAudioLevels = Array(repeating: CGFloat(0), count: 8)
    private var lastWaveUpdate = Date.distantPast
    private var currentState: RecordingOverlayState = .recording
    private var overlayGeneration = 0

    init() {
        panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 430, height: 92),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.ignoresMouseEvents = true
        panel.contentView = buildContent()
    }

    func showRecording() {
        advanceOverlayGeneration()
        currentState = .recording
        icon.contentTintColor = NSColor.systemRed
        refreshLocalizedText()
        label.textColor = textColor
        showWave(color: NSColor.systemRed)
        show()
    }

    func showProcessing() {
        advanceOverlayGeneration()
        currentState = .processing
        icon.contentTintColor = accentColor
        refreshLocalizedText()
        label.textColor = textColor
        showSpinner()
        show()
    }

    func showDone() {
        advanceOverlayGeneration()
        currentState = .done
        stopActivityIndicator()
        icon.contentTintColor = NSColor.systemGreen
        refreshLocalizedText()
        label.textColor = textColor
        show()
        hideAfterDelay()
    }

    func showCanceled() {
        advanceOverlayGeneration()
        currentState = .canceled
        stopActivityIndicator()
        icon.contentTintColor = NSColor.systemOrange
        refreshLocalizedText()
        label.textColor = textColor
        show()
        hideAfterDelay()
    }

    func showFailed() {
        advanceOverlayGeneration()
        currentState = .failed
        stopActivityIndicator()
        icon.contentTintColor = NSColor.systemRed
        refreshLocalizedText()
        label.textColor = textColor
        show()
        hideAfterDelay()
    }

    func refreshLocalizedText() {
        label.stringValue = currentState.labelText
    }

    func updateAudioLevel(_ level: Double) {
        guard currentState == .recording else {
            return
        }
        let clampedLevel = min(max(CGFloat(level), 0), 1)
        applyAudioLevel(clampedLevel)
    }

    func hide() {
        advanceOverlayGeneration()
        stopActivityIndicator()
        panel.orderOut(nil)
    }

    private func show() {
        positionPanel()
        panel.orderFrontRegardless()
    }

    private func hideAfterDelay() {
        let generation = overlayGeneration
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) { [weak self] in
            self?.hideIfGenerationMatches(generation)
        }
    }

    private func hideIfGenerationMatches(_ generation: Int) {
        guard generation == overlayGeneration else {
            return
        }
        hide()
    }

    private func advanceOverlayGeneration() {
        overlayGeneration &+= 1
    }

    private func buildContent() -> NSView {
        let container = RoundedView(
            fillColor: NSColor(calibratedRed: 0.96, green: 0.97, blue: 1, alpha: 0.97),
            strokeColor: NSColor(calibratedRed: 0.76, green: 0.82, blue: 0.98, alpha: 1),
            radius: 38
        )

        let iconBack = RoundedView(
            fillColor: NSColor(calibratedRed: 0.87, green: 0.91, blue: 1, alpha: 1),
            strokeColor: .clear,
            radius: 24
        )
        iconBack.addSubview(icon)

        indicatorHost.translatesAutoresizingMaskIntoConstraints = false

        barsStack.orientation = .horizontal
        barsStack.spacing = 5
        barsStack.alignment = .centerY
        barsStack.translatesAutoresizingMaskIntoConstraints = false
        for height in [16, 22, 28, 20, 30, 24, 18, 26] {
            let bar = RoundedView(fillColor: accentColor, strokeColor: .clear, radius: 3)
            barViews.append(bar)
            barsStack.addArrangedSubview(bar)
            let heightConstraint = bar.heightAnchor.constraint(equalToConstant: CGFloat(height))
            barHeightConstraints.append(heightConstraint)
            NSLayoutConstraint.activate([
                bar.widthAnchor.constraint(equalToConstant: 5),
                heightConstraint
            ])
        }
        indicatorHost.addSubview(barsStack)

        spinner.style = .spinning
        spinner.controlSize = .regular
        spinner.isIndeterminate = true
        spinner.isDisplayedWhenStopped = false
        spinner.translatesAutoresizingMaskIntoConstraints = false
        spinner.isHidden = true
        indicatorHost.addSubview(spinner)

        let row = NSStackView(views: [iconBack, indicatorHost, label])
        row.orientation = .horizontal
        row.spacing = 24
        row.alignment = .centerY
        row.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(row)

        NSLayoutConstraint.activate([
            iconBack.widthAnchor.constraint(equalToConstant: 48),
            iconBack.heightAnchor.constraint(equalToConstant: 48),
            icon.centerXAnchor.constraint(equalTo: iconBack.centerXAnchor),
            icon.centerYAnchor.constraint(equalTo: iconBack.centerYAnchor),
            indicatorHost.widthAnchor.constraint(equalToConstant: 86),
            indicatorHost.heightAnchor.constraint(equalToConstant: 42),
            barsStack.centerXAnchor.constraint(equalTo: indicatorHost.centerXAnchor),
            barsStack.centerYAnchor.constraint(equalTo: indicatorHost.centerYAnchor),
            spinner.centerXAnchor.constraint(equalTo: indicatorHost.centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: indicatorHost.centerYAnchor),
            row.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            row.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            row.leadingAnchor.constraint(greaterThanOrEqualTo: container.leadingAnchor, constant: 32),
            row.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor, constant: -32)
        ])

        return container
    }

    private func positionPanel() {
        guard let screen = NSScreen.main else {
            return
        }
        let frame = screen.visibleFrame
        let size = panel.frame.size
        let origin = NSPoint(
            x: frame.midX - size.width / 2,
            y: frame.minY + 86
        )
        panel.setFrameOrigin(origin)
    }

    private func showWave(color: NSColor) {
        spinner.stopAnimation(nil)
        spinner.isHidden = true
        barsStack.isHidden = false
        recentAudioLevels = Array(repeating: CGFloat(0), count: barHeightConstraints.count)
        lastWaveUpdate = Date.distantPast
        barViews.forEach { bar in
            bar.fillColor = color
            bar.needsLayout = true
        }
        applyAudioLevel(0)
    }

    private func showSpinner() {
        barsStack.isHidden = true
        spinner.isHidden = false
        spinner.startAnimation(nil)
    }

    private func applyAudioLevel(_ level: CGFloat) {
        guard !barHeightConstraints.isEmpty else {
            return
        }
        let now = Date()
        let noiseGate: CGFloat = 0.10
        let normalizedLevel: CGFloat
        if level < noiseGate {
            normalizedLevel = 0
        } else {
            normalizedLevel = min(max((level - noiseGate) / 0.65, 0), 1)
        }
        guard now.timeIntervalSince(lastWaveUpdate) >= 0.055 || normalizedLevel == 0 else {
            return
        }
        lastWaveUpdate = now
        if recentAudioLevels.count != barHeightConstraints.count {
            recentAudioLevels = Array(repeating: CGFloat(0), count: barHeightConstraints.count)
        }
        recentAudioLevels.removeFirst()
        recentAudioLevels.append(normalizedLevel)

        let floorHeight: CGFloat = 7
        let maxLift: CGFloat = 30
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.075
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            for (index, sample) in recentAudioLevels.enumerated() where index < barHeightConstraints.count {
                let perceptualLevel = pow(sample, 0.58)
                let height = floorHeight + maxLift * perceptualLevel
                barHeightConstraints[index].animator().constant = height
            }
            barsStack.layoutSubtreeIfNeeded()
        }
    }

    private func stopActivityIndicator() {
        spinner.stopAnimation(nil)
        spinner.isHidden = true
        barsStack.isHidden = true
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let projectDir = VoiceBankConfig.projectDirectory
    private let endpoint = VoiceBankConfig.endpoint
    private let healthURL = VoiceBankConfig.healthURL

    private var statusItem: NSStatusItem?
    private var voiceMenuItem: NSMenuItem?
    private var hotKeyMenuItem: NSMenuItem?
    private var accessibilityMenuItem: NSMenuItem?
    private var statusMenuItem: NSMenuItem?
    private var didInstallStatusItem = false
    private var currentStatus: VoiceBankStatus = .ready
    private var dashboardController: DashboardWindowController?
    private let overlayController = RecordingOverlayController()
    private let permissionsService = PermissionsService()
    private let audioLevelService = AudioLevelService()
    private lazy var voiceInputClient = VoiceInputClient(
        projectDir: projectDir,
        endpoint: endpoint,
        audioLevelService: audioLevelService
    )
    private lazy var pasteService = PasteService(permissions: permissionsService) { _ in }
    private lazy var recordingCoordinator = RecordingCoordinator(
        voiceInputClient: voiceInputClient,
        pasteService: pasteService,
        callbacks: RecordingCoordinatorCallbacks(
            setStatus: { [weak self] status in self?.setStatus(status) },
            setVoiceMenuTitle: { [weak self] title in self?.voiceMenuItem?.title = title },
            showRecording: { [weak self] in self?.overlayController.showRecording() },
            showProcessing: { [weak self] in self?.overlayController.showProcessing() },
            showDone: { [weak self] in self?.overlayController.showDone() },
            showCanceled: { [weak self] in self?.overlayController.showCanceled() },
            showFailed: { [weak self] in self?.overlayController.showFailed() },
            hideOverlay: { [weak self] in self?.overlayController.hide() },
            refreshHistory: { [weak self] in self?.dashboardController?.refreshStatsFromHistory() },
            refreshPermissions: { [weak self] in self?.refreshPermissionLabels() }
        )
    )
    private lazy var hotkeyService = HotkeyService(
        permissions: permissionsService,
        callbacks: HotkeyServiceCallbacks(
            toggleRecording: { [weak self] in self?.toggleRecording() },
            cancelRecording: { [weak self] in self?.cancelCurrentRecording() },
            updateHotkeyStatus: { [weak self] status in self?.dashboardController?.updateHotkeyStatus(status) },
            setStatus: { [weak self] status in self?.setStatus(status) },
            setHotkeyMenuTitle: { [weak self] title in self?.hotKeyMenuItem?.title = title }
        )
    )

    func applicationDidFinishLaunching(_ notification: Notification) {
        start()
    }

    func start() {
        guard !didInstallStatusItem else {
            return
        }
        didInstallStatusItem = true
        NSApp.setActivationPolicy(.accessory)

        let dashboard = DashboardWindowController()
        dashboardController = dashboard
        audioLevelService.onLevel = { [weak self] level in
            self?.overlayController.updateAudioLevel(level)
        }
        installStatusItem()
        requestRequiredPermissions()
        installRightOptionHotKey()
        dashboard.show()
        refreshPermissionLabels()
    }

    private func installStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem = item

        if let button = item.button {
            button.image = nil
            button.imagePosition = .noImage
            button.title = "V"
            button.toolTip = "Voice Bank"
        }

        item.menu = buildStatusMenu()
    }

    private func buildStatusMenu() -> NSMenu {
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: VoiceBankText.pick("Open Voice Bank", "打开 Voice Bank"), action: #selector(openDashboard), keyEquivalent: ""))

        let voiceItem = NSMenuItem(
            title: VoiceBankText.pick("Start/Stop Recording", "开始/结束录音"),
            action: #selector(toggleRecording),
            keyEquivalent: ""
        )
        voiceMenuItem = voiceItem
        menu.addItem(voiceItem)
        menu.addItem(NSMenuItem(
            title: VoiceBankText.pick("Cancel Current Recording", "取消当前录音"),
            action: #selector(cancelCurrentRecording),
            keyEquivalent: ""
        ))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(
            title: VoiceBankText.pick("Test Server", "测试服务端"),
            action: #selector(testConnection),
            keyEquivalent: ""
        ))
        menu.addItem(NSMenuItem(
            title: VoiceBankText.pick("Open Privacy Settings", "打开隐私设置"),
            action: #selector(openPrivacySettings),
            keyEquivalent: ""
        ))
        menu.addItem(.separator())

        let status = NSMenuItem(title: "\(VoiceBankText.pick("Status", "状态")): \(currentStatus.text)", action: nil, keyEquivalent: "")
        status.isEnabled = false
        statusMenuItem = status
        menu.addItem(status)

        let endpointItem = NSMenuItem(title: "\(VoiceBankText.pick("Endpoint", "服务端")): \(VoiceBankConfig.endpointDisplay)", action: nil, keyEquivalent: "")
        endpointItem.isEnabled = false
        menu.addItem(endpointItem)

        let hotKeyItem = NSMenuItem(title: VoiceBankText.pick("Hotkey: Right Option", "热键：右 Option"), action: nil, keyEquivalent: "")
        hotKeyItem.isEnabled = false
        hotKeyMenuItem = hotKeyItem
        menu.addItem(hotKeyItem)

        let accessibilityItem = NSMenuItem(title: VoiceBankText.pick("Accessibility: checking", "辅助功能：检查中"), action: nil, keyEquivalent: "")
        accessibilityItem.isEnabled = false
        accessibilityMenuItem = accessibilityItem
        menu.addItem(accessibilityItem)

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: VoiceBankText.pick("Open README", "打开 README"), action: #selector(openReadme), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: VoiceBankText.pick("Open Project Folder", "打开项目文件夹"), action: #selector(openProjectFolder), keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: VoiceBankText.pick("Quit Voice Bank", "退出 Voice Bank"), action: #selector(quit), keyEquivalent: "q"))

        return menu
    }

    @objc private func openDashboard() {
        dashboardController?.show()
    }

    @objc private func toggleRecording() {
        recordingCoordinator.toggle()
    }

    @objc private func cancelCurrentRecording() {
        recordingCoordinator.cancel()
    }

    @objc func changeLanguageMode(_ sender: NSPopUpButton) {
        guard let rawValue = sender.selectedItem?.representedObject as? String,
              let mode = VoiceBankLanguageMode(rawValue: rawValue) else {
            return
        }
        VoiceBankText.languageMode = mode
        refreshLocalizedInterface()
    }

    @objc func changeHistoryEnabled(_ sender: NSSwitch) {
        VoiceBankPreferences.saveLocalHistory = sender.state == .on
        if let dashboardController {
            dashboardController.showPage(dashboardController.selectedPage)
        }
    }

    @objc func changeHistoryRetention(_ sender: NSPopUpButton) {
        guard let days = sender.selectedItem?.representedObject as? Int else {
            return
        }
        VoiceBankPreferences.historyRetentionDays = days
    }

    @objc func clearLocalHistory() {
        guard !voiceInputClient.isRunning else {
            let alert = NSAlert()
            alert.messageText = VoiceBankText.pick("Recording is active", "正在录音或识别")
            alert.informativeText = VoiceBankText.pick("Finish or cancel the current recording before clearing history.", "请先结束或取消当前录音，再清空历史。")
            alert.runModal()
            return
        }

        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = VoiceBankText.pick("Delete all transcript history?", "删除全部转写历史？")
        alert.informativeText = VoiceBankText.pick("This permanently removes locally stored raw and polished text. This action cannot be undone.", "这会永久删除本机保存的原始转写与整理文字，且无法撤销。")
        alert.addButton(withTitle: VoiceBankText.pick("Delete All", "全部删除"))
        alert.addButton(withTitle: VoiceBankText.pick("Cancel", "取消"))
        guard alert.runModal() == .alertFirstButtonReturn else {
            return
        }

        do {
            try dashboardController?.historyStore.clearAll()
            if let dashboardController {
                dashboardController.showPage(.history)
            }
        } catch {
            let errorAlert = NSAlert(error: error)
            errorAlert.runModal()
        }
    }

    private func refreshLocalizedInterface() {
        statusItem?.menu = buildStatusMenu()
        recordingCoordinator.refreshLocalizedDisplay()
        dashboardController?.refreshLocalizedContent(currentStatus: currentStatus)
        overlayController.refreshLocalizedText()
        refreshPermissionLabels()
        setStatus(currentStatus)
    }

    private func refreshPermissionLabels() {
        let accessibilityTrusted = permissionsService.isAccessibilityTrusted()
        accessibilityMenuItem?.title = accessibilityTrusted ? VoiceBankText.pick("Accessibility: allowed", "辅助功能：已允许") : VoiceBankText.pick("Accessibility: not allowed", "辅助功能：未允许")

        let inputAllowed = permissionsService.isInputMonitoringAllowed()
        hotKeyMenuItem?.title = inputAllowed ? VoiceBankText.pick("Hotkey: Right Option", "热键：右 Option") : VoiceBankText.pick("Hotkey: Right Option (needs permission)", "热键：右 Option（需要权限）")
        dashboardController?.updateHotkeyStatus(inputAllowed ? VoiceBankText.pick("Right Option is listening", "右 Option 正在监听") : VoiceBankText.pick("Input Monitoring permission required", "需要输入监控权限"))
    }

    @objc private func testConnection() {
        setStatus(.testingMini)
        var request = URLRequest(url: healthURL)
        if let serverToken = VoiceBankConfig.serverToken {
            request.setValue("Bearer \(serverToken)", forHTTPHeaderField: "Authorization")
        }
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                if let error {
                    self?.setStatus(.miniFailed(error.localizedDescription))
                    return
                }
                guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                    self?.setStatus(.miniFailedBadStatus)
                    return
                }
                let body = data.flatMap { String(data: $0, encoding: .utf8) } ?? ""
                if body.contains("voice_bank_voice_input") || body.contains("\"ok\":true") {
                    self?.setStatus(.miniOK)
                } else {
                    self?.setStatus(.miniReachable)
                }
            }
        }.resume()
    }

    @objc func requestRequiredPermissions() {
        let accessibilityTrusted = permissionsService.requestAccessibilityIfNeeded()
        if !accessibilityTrusted {
            setStatus(.allowAccessibility)
        }

        if !permissionsService.isInputMonitoringAllowed() {
            hotKeyMenuItem?.title = VoiceBankText.pick("Hotkey: Right Option (needs permission)", "热键：右 Option（需要权限）")
            dashboardController?.updateHotkeyStatus(VoiceBankText.pick("Input Monitoring permission required", "需要输入监控权限"))
            setStatus(.allowInputMonitoring)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                _ = self.permissionsService.requestInputMonitoring()
            }
        }
        refreshPermissionLabels()
    }

    @objc func openPrivacySettings() {
        permissionsService.openInputMonitoringSettings()
    }

    @objc private func openReadme() {
        NSWorkspace.shared.open(URL(fileURLWithPath: "\(projectDir)/README.md"))
    }

    @objc private func openProjectFolder() {
        NSWorkspace.shared.open(URL(fileURLWithPath: projectDir, isDirectory: true))
    }

    @objc private func quit() {
        recordingCoordinator.terminateForQuit()
        hotkeyService.remove()
        NSApp.terminate(nil)
    }

    private func setStatus(_ status: VoiceBankStatus) {
        currentStatus = status
        statusMenuItem?.title = "\(VoiceBankText.pick("Status", "状态")): \(status.text)"
        dashboardController?.updateStatus(status)
    }

    private func installRightOptionHotKey() {
        hotkeyService.install()
    }

    private func wordCount(from output: String) -> Int {
        guard let line = output.split(separator: "\n").first(where: { $0.contains("输出文本") }) else {
            return 0
        }
        let text = line.split(separator: ":").dropFirst().joined(separator: ":")
        return text.split { $0.isWhitespace || $0.isPunctuation }.count
    }
}
