import AppKit

extension DashboardWindowController {
    func refreshStatsFromHistory() {
        let stats = historyStore.stats()
        wordsTodayLabel.stringValue = "\(stats.todayChars)"
        totalWordsLabel.stringValue = "\(stats.totalChars)"
    }

    func buildRootView() -> NSView {
        let root = NSView()
        root.wantsLayer = true
        root.layer?.backgroundColor = dashboardBackgroundColor.cgColor

        sidebarHost.translatesAutoresizingMaskIntoConstraints = false
        contentHost.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(sidebarHost)
        root.addSubview(contentHost)
        refreshSidebar()

        NSLayoutConstraint.activate([
            sidebarHost.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            sidebarHost.topAnchor.constraint(equalTo: root.topAnchor),
            sidebarHost.bottomAnchor.constraint(equalTo: root.bottomAnchor),
            sidebarHost.widthAnchor.constraint(equalToConstant: 220),
            contentHost.leadingAnchor.constraint(equalTo: sidebarHost.trailingAnchor),
            contentHost.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            contentHost.topAnchor.constraint(equalTo: root.topAnchor),
            contentHost.bottomAnchor.constraint(equalTo: root.bottomAnchor)
        ])

        return root
    }

    func refreshSidebar() {
        sidebarHost.subviews.forEach { $0.removeFromSuperview() }
        let sidebar = buildSidebar()
        sidebarHost.addSubview(sidebar)
        NSLayoutConstraint.activate([
            sidebar.leadingAnchor.constraint(equalTo: sidebarHost.leadingAnchor),
            sidebar.trailingAnchor.constraint(equalTo: sidebarHost.trailingAnchor),
            sidebar.topAnchor.constraint(equalTo: sidebarHost.topAnchor),
            sidebar.bottomAnchor.constraint(equalTo: sidebarHost.bottomAnchor)
        ])
    }

    func buildSidebar() -> NSView {
        let sidebar = NSView()
        sidebar.translatesAutoresizingMaskIntoConstraints = false
        sidebar.wantsLayer = true
        sidebar.layer?.backgroundColor = NSColor.white.cgColor
        sidebar.layer?.borderColor = lineColor.cgColor
        sidebar.layer?.borderWidth = 1

        let home = navRow(title: VoiceBankText.pick("Home", "首页"), symbol: "house", selected: selectedPage == .home, action: #selector(showHomePage))
        let history = navRow(title: VoiceBankText.pick("History", "历史"), symbol: "clock.arrow.circlepath", selected: selectedPage == .history, action: #selector(showHistoryPage))
        let version = makeLabel("v0.1.0", size: 12, color: NSColor(calibratedWhite: 0.82, alpha: 1), alignment: .center)
        let powered = makeLabel("Voice Bank", size: 13, weight: .semibold, color: accentColor, alignment: .center)

        let stack = NSStackView(views: [home, history])
        stack.orientation = .vertical
        stack.spacing = 12
        stack.alignment = .leading
        stack.translatesAutoresizingMaskIntoConstraints = false
        sidebar.addSubview(stack)
        sidebar.addSubview(version)
        sidebar.addSubview(powered)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: sidebar.leadingAnchor, constant: 18),
            stack.trailingAnchor.constraint(equalTo: sidebar.trailingAnchor, constant: -18),
            stack.topAnchor.constraint(equalTo: sidebar.topAnchor, constant: 92),
            version.centerXAnchor.constraint(equalTo: sidebar.centerXAnchor),
            version.bottomAnchor.constraint(equalTo: powered.topAnchor, constant: -10),
            powered.centerXAnchor.constraint(equalTo: sidebar.centerXAnchor),
            powered.bottomAnchor.constraint(equalTo: sidebar.bottomAnchor, constant: -28)
        ])

        return sidebar
    }

    func navRow(title: String, symbol: String, selected: Bool, action: Selector? = nil) -> NSView {
        let row = RoundedView(
            fillColor: selected ? NSColor(calibratedRed: 0.91, green: 0.95, blue: 1, alpha: 1) : .clear,
            strokeColor: .clear,
            radius: 8
        )
        row.toolTip = title
        let icon = makeSymbol(symbol, pointSize: 18, color: selected ? accentColor : mutedTextColor)
        let label = makeLabel(title, size: 17, weight: .medium, color: selected ? accentColor : mutedTextColor)

        let stack = NSStackView(views: [icon, label])
        stack.orientation = .horizontal
        stack.spacing = 12
        stack.alignment = .centerY
        stack.translatesAutoresizingMaskIntoConstraints = false
        row.addSubview(stack)

        NSLayoutConstraint.activate([
            row.widthAnchor.constraint(equalToConstant: 184),
            row.heightAnchor.constraint(equalToConstant: 46),
            stack.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: 18),
            stack.centerYAnchor.constraint(equalTo: row.centerYAnchor)
        ])

        if let action {
            row.addGestureRecognizer(NSClickGestureRecognizer(target: self, action: action))
        }

        return row
    }

    @objc func showHomePage() {
        showPage(.home)
    }

    @objc func showHistoryPage() {
        showPage(.history)
    }

    @objc func openLocalHistoryFolder() {
        NSWorkspace.shared.open(historyFolderURL)
    }

    func refreshLocalizedContent(currentStatus: VoiceBankStatus) {
        let page = selectedPage
        let scrollOrigin = activeScrollOrigin()
        hotkeyStatusLabel.stringValue = VoiceBankText.pick("Right Option is listening", "右 Option 正在监听")
        showPage(page)
        updateStatus(currentStatus)
        restoreActiveScrollOrigin(scrollOrigin)
    }

    func showPage(_ page: DashboardPage) {
        selectedPage = page
        refreshStatsFromHistory()
        refreshSidebar()
        let view = page == .home ? buildHomeContent() : buildHistoryContent()
        contentHost.subviews.forEach { $0.removeFromSuperview() }
        contentHost.addSubview(view)
        NSLayoutConstraint.activate([
            view.leadingAnchor.constraint(equalTo: contentHost.leadingAnchor),
            view.trailingAnchor.constraint(equalTo: contentHost.trailingAnchor),
            view.topAnchor.constraint(equalTo: contentHost.topAnchor),
            view.bottomAnchor.constraint(equalTo: contentHost.bottomAnchor)
        ])
    }

    func activeScrollOrigin() -> NSPoint? {
        activeScrollView(in: contentHost)?.contentView.bounds.origin
    }

    func restoreActiveScrollOrigin(_ origin: NSPoint?) {
        guard let origin, let scrollView = activeScrollView(in: contentHost) else {
            return
        }

        scrollView.layoutSubtreeIfNeeded()
        let documentSize = scrollView.documentView?.bounds.size ?? .zero
        let visibleSize = scrollView.contentView.bounds.size
        let x = min(max(origin.x, 0), max(documentSize.width - visibleSize.width, 0))
        let y = min(max(origin.y, 0), max(documentSize.height - visibleSize.height, 0))
        scrollView.contentView.scroll(to: NSPoint(x: x, y: y))
        scrollView.reflectScrolledClipView(scrollView.contentView)
    }

    func activeScrollView(in view: NSView) -> NSScrollView? {
        if let scrollView = view as? NSScrollView {
            return scrollView
        }
        for subview in view.subviews {
            if let scrollView = activeScrollView(in: subview) {
                return scrollView
            }
        }
        return nil
    }

    func buildHomeContent() -> NSView {
        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = false

        let content = FlippedView()
        content.translatesAutoresizingMaskIntoConstraints = false
        scrollView.documentView = content

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 18
        stack.alignment = .leading
        stack.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(stack)

        stack.addArrangedSubview(buildHeroCard())
        stack.addArrangedSubview(buildStatsRow())
        stack.addArrangedSubview(buildHotkeySection())
        stack.addArrangedSubview(buildOptionsSection())
        stack.addArrangedSubview(buildPreferencesSection())
        stack.addArrangedSubview(buildPermissionSection())

        NSLayoutConstraint.activate([
            content.widthAnchor.constraint(equalTo: scrollView.contentView.widthAnchor),
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 34),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -34),
            stack.topAnchor.constraint(equalTo: content.topAnchor, constant: 34),
            stack.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -34)
        ])

        return scrollView
    }

    func buildHistoryContent() -> NSView {
        let entries = historyStore.loadEntries()
        let groups = historyStore.dayGroups(for: entries)
        let stats = historyStore.stats(for: entries)
        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = false

        let content = FlippedView()
        content.translatesAutoresizingMaskIntoConstraints = false
        scrollView.documentView = content

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 14
        stack.alignment = .leading
        stack.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(stack)

        let header = buildHistoryHeader(stats: stats)
        stack.addArrangedSubview(header)
        header.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true

        if entries.isEmpty {
            let empty = RoundedView(fillColor: .white, strokeColor: lineColor, radius: 14)
            let emptyText = VoiceBankPreferences.saveLocalHistory
                ? VoiceBankText.pick("No history yet. Press Right Option to record; successful transcriptions will appear here.", "还没有历史记录。按右 Option 开始录音，识别成功后会出现在这里。")
                : VoiceBankText.pick("History is off. Enable it in Home > Options if you want Voice Bank to retain transcript text.", "历史记录已关闭。如需保留转写文字，请在“首页 > 选项”中主动开启。")
            let label = makeLabel(emptyText, size: 15, color: mutedTextColor)
            label.lineBreakMode = .byWordWrapping
            label.maximumNumberOfLines = 0
            empty.addSubview(label)
            NSLayoutConstraint.activate([
                empty.heightAnchor.constraint(equalToConstant: 92),
                label.leadingAnchor.constraint(equalTo: empty.leadingAnchor, constant: 22),
                label.trailingAnchor.constraint(equalTo: empty.trailingAnchor, constant: -22),
                label.centerYAnchor.constraint(equalTo: empty.centerYAnchor)
            ])
            stack.addArrangedSubview(empty)
            empty.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        } else {
            var renderedCount = 0
            for group in groups {
                guard renderedCount < 120 else {
                    break
                }
                let groupHeader = buildHistoryGroupHeader(group)
                stack.addArrangedSubview(groupHeader)
                groupHeader.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
                for entry in group.entries {
                    guard renderedCount < 120 else {
                        break
                    }
                    let row = buildHistoryEntryRow(entry)
                    stack.addArrangedSubview(row)
                    row.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
                    renderedCount += 1
                }
            }
        }

        NSLayoutConstraint.activate([
            content.widthAnchor.constraint(equalTo: scrollView.contentView.widthAnchor),
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 34),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -34),
            stack.topAnchor.constraint(equalTo: content.topAnchor, constant: 34),
            stack.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -34)
        ])

        return scrollView
    }

    func buildHistoryHeader(stats: HistoryStats) -> NSView {
        let card = RoundedView(fillColor: .white, strokeColor: lineColor, radius: 16)
        let title = makeLabel(VoiceBankText.pick("History", "历史"), size: 26, weight: .bold)
        let subtitle = makeLabel(VoiceBankText.pick("\(stats.entryCount) entries · \(stats.todayChars) chars today · \(stats.totalChars) total chars", "\(stats.entryCount) 条记录 · 今日 \(stats.todayChars) 字 · 累计 \(stats.totalChars) 字"), size: 14, color: mutedTextColor)
        subtitle.lineBreakMode = .byWordWrapping
        subtitle.maximumNumberOfLines = 2
        let labels = NSStackView(views: [title, subtitle])
        labels.orientation = .vertical
        labels.spacing = 5
        labels.alignment = .leading
        labels.translatesAutoresizingMaskIntoConstraints = false
        labels.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        let openButton = NSButton(title: VoiceBankText.pick("Open Folder", "打开文件夹"), target: self, action: #selector(openLocalHistoryFolder))
        openButton.bezelStyle = .rounded
        openButton.translatesAutoresizingMaskIntoConstraints = false

        let row = NSStackView(views: [labels, NSView(), openButton])
        row.orientation = .horizontal
        row.spacing = 18
        row.alignment = .centerY
        row.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(row)

        NSLayoutConstraint.activate([
            card.heightAnchor.constraint(equalToConstant: 104),
            row.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 26),
            row.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -26),
            row.centerYAnchor.constraint(equalTo: card.centerYAnchor)
        ])
        return card
    }

    func buildHistoryGroupHeader(_ group: HistoryDayGroup) -> NSView {
        let label = makeLabel(group.title, size: 14, weight: .semibold, color: mutedTextColor)
        let count = makeLabel("\(group.entries.count)", size: 12, weight: .medium, color: NSColor(calibratedWhite: 0.64, alpha: 1))
        let row = NSStackView(views: [label, count])
        row.orientation = .horizontal
        row.spacing = 8
        row.alignment = .lastBaseline
        row.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            row.heightAnchor.constraint(equalToConstant: 24)
        ])
        return row
    }

    func buildHistoryEntryRow(_ entry: HistoryEntry) -> NSView {
        let card = RoundedView(fillColor: .white, strokeColor: lineColor, radius: 12)
        let meta = makeLabel(VoiceBankText.pick("\(entry.date) \(entry.time) · \(entry.textChars) chars", "\(entry.date) \(entry.time) · \(entry.textChars) 字"), size: 12, weight: .medium, color: mutedTextColor)
        let text = makeLabel(entry.text, size: 15, color: textColor)
        text.lineBreakMode = .byWordWrapping
        text.maximumNumberOfLines = 6
        text.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        text.setContentHuggingPriority(.defaultLow, for: .horizontal)
        meta.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        let stack = NSStackView(views: [meta, text])
        stack.orientation = .vertical
        stack.spacing = 7
        stack.alignment = .width
        stack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(stack)

        NSLayoutConstraint.activate([
            card.heightAnchor.constraint(greaterThanOrEqualToConstant: 88),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -20),
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16),
            meta.widthAnchor.constraint(equalTo: stack.widthAnchor),
            text.widthAnchor.constraint(equalTo: stack.widthAnchor)
        ])
        return card
    }

    func buildHeroCard() -> NSView {
        let card = RoundedView(fillColor: .white, strokeColor: lineColor, radius: 16)

        let logo = RoundedView(fillColor: textColor, strokeColor: .clear, radius: 12)
        let logoLabel = makeLabel("V", size: 34, weight: .heavy, color: .white, alignment: .center)
        logo.addSubview(logoLabel)

        let title = makeLabel("Voice Bank - Just Speak It", size: 26, weight: .bold)
        let subtitle = makeLabel(VoiceBankText.pick("Press Right Option once to record, press again to transcribe and paste.", "按一次右 Option 开始录音，再按一次识别并粘贴。"), size: 14, color: mutedTextColor)
        let titleStack = NSStackView(views: [title, subtitle])
        titleStack.orientation = .vertical
        titleStack.spacing = 5
        titleStack.alignment = .leading
        titleStack.translatesAutoresizingMaskIntoConstraints = false

        statusDot.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            statusDot.widthAnchor.constraint(equalToConstant: 10),
            statusDot.heightAnchor.constraint(equalToConstant: 10)
        ])

        let statusRow = NSStackView(views: [statusDot, statusLabel])
        statusRow.orientation = .horizontal
        statusRow.spacing = 8
        statusRow.alignment = .centerY
        statusRow.translatesAutoresizingMaskIntoConstraints = false

        let row = NSStackView(views: [logo, titleStack, NSView(), statusRow])
        row.orientation = .horizontal
        row.spacing = 20
        row.alignment = .centerY
        row.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(row)

        NSLayoutConstraint.activate([
            card.heightAnchor.constraint(equalToConstant: 116),
            logo.widthAnchor.constraint(equalToConstant: 66),
            logo.heightAnchor.constraint(equalToConstant: 66),
            logoLabel.centerXAnchor.constraint(equalTo: logo.centerXAnchor),
            logoLabel.centerYAnchor.constraint(equalTo: logo.centerYAnchor),
            row.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 28),
            row.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -28),
            row.centerYAnchor.constraint(equalTo: card.centerYAnchor)
        ])

        return card
    }

    func buildStatsRow() -> NSView {
        let first = RoundedView(fillColor: .white, strokeColor: lineColor, radius: 14)
        let second = RoundedView(fillColor: .white, strokeColor: lineColor, radius: 14)
        fillStatCard(first, symbol: "mic.fill", valueLabel: wordsTodayLabel, unit: VoiceBankText.pick("chars", "字"), caption: VoiceBankText.pick("Chars today", "今日字数"))
        fillStatCard(second, symbol: "doc.text.fill", valueLabel: totalWordsLabel, unit: VoiceBankText.pick("chars", "字"), caption: VoiceBankText.pick("Total chars", "累计字数"))

        let row = NSStackView(views: [first, second])
        row.orientation = .horizontal
        row.spacing = 16
        row.distribution = .fillEqually
        row.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            row.heightAnchor.constraint(equalToConstant: 104)
        ])
        return row
    }

    func fillStatCard(_ card: RoundedView, symbol: String, valueLabel: NSTextField, unit: String, caption: String) {
        let icon = makeSymbol(symbol, pointSize: 30, color: accentColor)
        let unitLabel = makeLabel(unit, size: 13, weight: .medium, color: mutedTextColor)
        let captionLabel = makeLabel(caption, size: 13, color: NSColor(calibratedWhite: 0.68, alpha: 1))

        let valueRow = NSStackView(views: [valueLabel, unitLabel])
        valueRow.orientation = .horizontal
        valueRow.spacing = 8
        valueRow.alignment = .lastBaseline
        valueRow.translatesAutoresizingMaskIntoConstraints = false

        let textStack = NSStackView(views: [valueRow, captionLabel])
        textStack.orientation = .vertical
        textStack.spacing = 3
        textStack.alignment = .leading
        textStack.translatesAutoresizingMaskIntoConstraints = false

        let row = NSStackView(views: [icon, textStack])
        row.orientation = .horizontal
        row.spacing = 16
        row.alignment = .centerY
        row.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(row)

        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 24),
            row.trailingAnchor.constraint(lessThanOrEqualTo: card.trailingAnchor, constant: -24),
            row.centerYAnchor.constraint(equalTo: card.centerYAnchor)
        ])
    }

    func buildHotkeySection() -> NSView {
        let section = RoundedView(fillColor: .white, strokeColor: lineColor, radius: 14)
        let hotkeyRow = SettingRowView(
            title: VoiceBankText.pick("Recording Hotkey", "录音热键"),
            subtitle: VoiceBankText.pick("Short press = toggle mode. Press once to start, press again to stop.", "短按切换状态。按一次开始，再按一次结束。"),
            trailing: PillView("Right Option")
        )
        let statusRow = SettingRowView(
            title: VoiceBankText.pick("Hotkey Status", "热键状态"),
            subtitle: nil,
            trailing: hotkeyStatusLabel
        )
        let cancelRow = SettingRowView(
            title: VoiceBankText.pick("Cancel Recording", "取消录音"),
            subtitle: VoiceBankText.pick("Stops the current recording or processing job without pasting.", "停止当前录音或识别任务，不粘贴结果。"),
            trailing: PillView("Esc")
        )
        addRows([hotkeyRow, statusRow, cancelRow], to: section)
        return section
    }

    func buildOptionsSection() -> NSView {
        let section = RoundedView(fillColor: .white, strokeColor: lineColor, radius: 14)
        let polishSwitch = NSSwitch()
        polishSwitch.state = .on
        polishSwitch.isEnabled = false
        let soundSwitch = NSSwitch()
        soundSwitch.state = .off
        soundSwitch.isEnabled = false
        let historySwitch = NSSwitch()
        historySwitch.state = VoiceBankPreferences.saveLocalHistory ? .on : .off
        historySwitch.target = NSApp.delegate
        historySwitch.action = #selector(AppDelegate.changeHistoryEnabled(_:))
        addRows([
            SettingRowView(title: VoiceBankText.pick("Text Polish", "文本润色"), trailing: polishSwitch),
            SettingRowView(title: VoiceBankText.pick("Sound Feedback", "声音反馈"), trailing: soundSwitch),
            SettingRowView(
                title: VoiceBankText.pick("Save Transcript History", "保存转写历史"),
                subtitle: VoiceBankText.pick("Off by default. When enabled, text is stored locally for the selected retention period.", "默认关闭。开启后，文字只在本机保存，并按所选期限自动清理。"),
                trailing: historySwitch
            ),
            SettingRowView(title: VoiceBankText.pick("History Retention", "历史保留期限"), trailing: historyRetentionPopup()),
            SettingRowView(
                title: VoiceBankText.pick("Delete History", "删除历史"),
                subtitle: VoiceBankText.pick("Permanently removes all locally stored transcript text.", "永久删除本机保存的全部转写文字。"),
                trailing: actionPill(VoiceBankText.pick("Clear All", "全部清空"), selector: #selector(AppDelegate.clearLocalHistory))
            )
        ], to: section)
        return section
    }

    func historyRetentionPopup() -> NSPopUpButton {
        let popup = NSPopUpButton(frame: .zero, pullsDown: false)
        popup.translatesAutoresizingMaskIntoConstraints = false
        popup.target = NSApp.delegate
        popup.action = #selector(AppDelegate.changeHistoryRetention(_:))
        popup.isEnabled = VoiceBankPreferences.saveLocalHistory
        for days in VoiceBankPreferences.retentionOptions {
            popup.addItem(withTitle: VoiceBankText.pick("\(days) days", "\(days) 天"))
            popup.lastItem?.representedObject = days
        }
        if let index = VoiceBankPreferences.retentionOptions.firstIndex(of: VoiceBankPreferences.historyRetentionDays) {
            popup.selectItem(at: index)
        }
        NSLayoutConstraint.activate([
            popup.heightAnchor.constraint(equalToConstant: 32),
            popup.widthAnchor.constraint(greaterThanOrEqualToConstant: 150)
        ])
        return popup
    }

    func buildPreferencesSection() -> NSView {
        let section = RoundedView(fillColor: .white, strokeColor: lineColor, radius: 14)
        addRows([
            SettingRowView(title: VoiceBankText.pick("Language", "语言"), trailing: languagePopup()),
            SettingRowView(title: VoiceBankText.pick("Appearance", "外观"), trailing: PillView(VoiceBankText.pick("System", "跟随系统"))),
            SettingRowView(title: VoiceBankText.pick("Voice Server", "语音服务"), subtitle: VoiceBankConfig.endpointDisplay, trailing: PillView(VoiceBankText.pick("Configured", "已配置")))
        ], to: section)
        return section
    }

    func languagePopup() -> NSPopUpButton {
        let popup = NSPopUpButton(frame: .zero, pullsDown: false)
        popup.translatesAutoresizingMaskIntoConstraints = false
        popup.target = NSApp.delegate
        popup.action = #selector(AppDelegate.changeLanguageMode(_:))

        for mode in VoiceBankLanguageMode.allCases {
            popup.addItem(withTitle: mode.title)
            popup.lastItem?.representedObject = mode.rawValue
        }

        if let index = VoiceBankLanguageMode.allCases.firstIndex(of: VoiceBankText.languageMode) {
            popup.selectItem(at: index)
        }

        NSLayoutConstraint.activate([
            popup.heightAnchor.constraint(equalToConstant: 32),
            popup.widthAnchor.constraint(greaterThanOrEqualToConstant: 150)
        ])
        return popup
    }

    func buildPermissionSection() -> NSView {
        let section = RoundedView(fillColor: .white, strokeColor: lineColor, radius: 14)
        addRows([
            SettingRowView(title: VoiceBankText.pick("Permissions", "权限"), subtitle: VoiceBankText.pick("Microphone, Accessibility, and Input Monitoring are required for hotkey recording and auto paste.", "需要麦克风、辅助功能和输入监控权限，才能使用热键录音和自动粘贴。")),
            SettingRowView(title: VoiceBankText.pick("Request Permissions", "申请权限"), subtitle: VoiceBankText.pick("Ask macOS to add Voice Bank to the required privacy lists.", "让 macOS 打开 Voice Bank 需要的隐私权限列表。"), trailing: actionPill(VoiceBankText.pick("Request", "申请"), selector: #selector(AppDelegate.requestRequiredPermissions))),
            SettingRowView(title: VoiceBankText.pick("Open Privacy Settings", "打开隐私设置"), trailing: actionPill(VoiceBankText.pick("System Settings", "系统设置"), selector: #selector(AppDelegate.openPrivacySettings)))
        ], to: section)
        return section
    }

    func actionPill(_ title: String, selector: Selector) -> NSButton {
        let button = NSButton(title: title, target: NSApp.delegate, action: selector)
        button.bezelStyle = .rounded
        button.font = .monospacedSystemFont(ofSize: 15, weight: .semibold)
        button.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            button.heightAnchor.constraint(equalToConstant: 34),
            button.widthAnchor.constraint(greaterThanOrEqualToConstant: 150)
        ])
        return button
    }

    func addRows(_ rows: [NSView], to section: RoundedView) {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 0
        stack.alignment = .leading
        stack.translatesAutoresizingMaskIntoConstraints = false
        section.addSubview(stack)

        for (index, row) in rows.enumerated() {
            stack.addArrangedSubview(row)
            row.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
            if index < rows.count - 1 {
                let separator = NSBox()
                separator.boxType = .separator
                separator.translatesAutoresizingMaskIntoConstraints = false
                stack.addArrangedSubview(separator)
                separator.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
            }
        }

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: section.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: section.trailingAnchor),
            stack.topAnchor.constraint(equalTo: section.topAnchor),
            stack.bottomAnchor.constraint(equalTo: section.bottomAnchor)
        ])
    }
}
