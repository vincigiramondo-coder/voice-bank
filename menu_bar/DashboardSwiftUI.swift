import AppKit
import SwiftUI

enum VoiceBankAppearanceMode: String, CaseIterable {
    case system
    case light
    case dark

    private static let defaultsKey = "voicebank.appearanceMode"

    var title: String {
        switch self {
        case .system:
            return VoiceBankText.pick("System", "跟随系统")
        case .light:
            return VoiceBankText.pick("Light", "浅色")
        case .dark:
            return VoiceBankText.pick("Dark", "深色")
        }
    }

    static var current: VoiceBankAppearanceMode {
        get {
            let value = UserDefaults.standard.string(forKey: defaultsKey) ?? Self.system.rawValue
            return VoiceBankAppearanceMode(rawValue: value) ?? .system
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: defaultsKey)
            newValue.apply()
        }
    }

    func apply() {
        switch self {
        case .system:
            NSApp.appearance = nil
        case .light:
            NSApp.appearance = NSAppearance(named: .aqua)
        case .dark:
            NSApp.appearance = NSAppearance(named: .darkAqua)
        }
    }
}

final class DashboardViewModel: ObservableObject {
    @Published var selectedPage: DashboardPage = .home
    @Published var status: VoiceBankStatus = .ready
    @Published var hotkeyStatus: String = VoiceBankText.pick("Right Option is listening", "右 Option 正在监听")
    @Published var stats: HistoryStats
    @Published var historyEntries: [HistoryEntry]
    @Published var historyGroups: [HistoryDayGroup]
    @Published var languageMode: VoiceBankLanguageMode = VoiceBankText.languageMode
    @Published var appearanceMode: VoiceBankAppearanceMode = VoiceBankAppearanceMode.current
    @Published var serverEndpoint: String = VoiceBankConfig.endpointDisplay

    let historyStore: HistoryStore
    var requestPermissions: (() -> Void)?
    var openPrivacySettings: (() -> Void)?
    var testMini: (() -> Void)?
    var configureServer: (() -> Void)?

    init(historyStore: HistoryStore = HistoryStore()) {
        self.historyStore = historyStore
        let entries = historyStore.loadEntries()
        self.historyEntries = entries
        self.historyGroups = historyStore.dayGroups(for: entries)
        self.stats = historyStore.stats(for: entries)
        VoiceBankAppearanceMode.current.apply()
    }

    var historyFolderURL: URL {
        historyStore.historyFolderURL
    }

    func refreshHistory() {
        let entries = historyStore.loadEntries()
        historyEntries = entries
        historyGroups = historyStore.dayGroups(for: entries)
        stats = historyStore.stats(for: entries)
    }

    func updateStatus(_ newStatus: VoiceBankStatus) {
        status = newStatus
    }

    func updateHotkeyStatus(_ newStatus: String) {
        hotkeyStatus = newStatus
    }

    func refreshServerEndpoint() {
        serverEndpoint = VoiceBankConfig.endpointDisplay
    }

    func refreshLocalizedContent(currentStatus: VoiceBankStatus) {
        languageMode = VoiceBankText.languageMode
        hotkeyStatus = VoiceBankText.pick("Right Option is listening", "右 Option 正在监听")
        status = currentStatus
        refreshHistory()
    }

    func setLanguageMode(_ mode: VoiceBankLanguageMode) {
        VoiceBankText.languageMode = mode
        languageMode = mode
        refreshLocalizedContent(currentStatus: status)
    }

    func setAppearanceMode(_ mode: VoiceBankAppearanceMode) {
        VoiceBankAppearanceMode.current = mode
        appearanceMode = mode
    }

    func openHistoryFolder() {
        NSWorkspace.shared.open(historyFolderURL)
    }
}

struct VoiceBankDashboardView: View {
    @ObservedObject var model: DashboardViewModel

    var body: some View {
        NavigationSplitView {
            List(selection: $model.selectedPage) {
                Section {
                    ForEach(DashboardPage.allCases, id: \.self) { page in
                        Label(page.title, systemImage: page.symbolName)
                            .tag(page)
                    }
                }
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Voice Bank")
                            .font(.caption.weight(.semibold))
                        Text("v\(VoiceBankConfig.appVersion)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 6)
                }
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 180, ideal: 220)
        } detail: {
            Group {
                switch model.selectedPage {
                case .home:
                    HomeDashboardView(model: model)
                case .history:
                    HistoryDashboardView(model: model)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(nsColor: .windowBackgroundColor))
        }
    }
}

private struct HomeDashboardView: View {
    @ObservedObject var model: DashboardViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: VoiceBankUI.space24) {
                HeaderView(model: model)
                HStack(spacing: VoiceBankUI.space16) {
                    StatTile(
                        title: VoiceBankText.pick("Chars today", "今日字数"),
                        value: model.stats.todayChars,
                        symbol: "mic.fill"
                    )
                    StatTile(
                        title: VoiceBankText.pick("Total chars", "累计字数"),
                        value: model.stats.totalChars,
                        symbol: "doc.text.fill"
                    )
                }

                NativeGroup(VoiceBankText.pick("Recording", "录音")) {
                    InfoRow(
                        title: VoiceBankText.pick("Recording Hotkey", "录音热键"),
                        subtitle: VoiceBankText.pick("Press once to start, press again to stop.", "按一次开始，再按一次结束。"),
                        systemImage: "keyboard",
                        trailing: { KeyCapsule("Right Option") }
                    )
                    Divider()
                    InfoRow(
                        title: VoiceBankText.pick("Hotkey Status", "热键状态"),
                        subtitle: model.hotkeyStatus,
                        systemImage: "checkmark.circle"
                    )
                    Divider()
                    InfoRow(
                        title: VoiceBankText.pick("Cancel Recording", "取消录音"),
                        subtitle: VoiceBankText.pick("Stop the current recording or processing job without pasting.", "停止当前录音或识别任务，不粘贴结果。"),
                        systemImage: "escape",
                        trailing: { KeyCapsule("Esc") }
                    )
                }

                NativeGroup(VoiceBankText.pick("Preferences", "偏好")) {
                    PickerRow(
                        title: VoiceBankText.pick("Language", "语言"),
                        systemImage: "character.bubble",
                        selection: Binding(
                            get: { model.languageMode },
                            set: { model.setLanguageMode($0) }
                        ),
                        values: VoiceBankLanguageMode.allCases,
                        titleForValue: { $0.title }
                    )
                    Divider()
                    PickerRow(
                        title: VoiceBankText.pick("Appearance", "外观"),
                        systemImage: "circle.lefthalf.filled",
                        selection: Binding(
                            get: { model.appearanceMode },
                            set: { model.setAppearanceMode($0) }
                        ),
                        values: VoiceBankAppearanceMode.allCases,
                        titleForValue: { $0.title }
                    )
                    Divider()
                    InfoRow(
                        title: VoiceBankText.pick("Mini Server", "Mini 服务"),
                        subtitle: model.serverEndpoint,
                        systemImage: "server.rack",
                        trailing: {
                            HStack(spacing: 8) {
                                Button(VoiceBankText.pick("Change", "设置")) {
                                    model.configureServer?()
                                }
                                Button(VoiceBankText.pick("Test", "测试")) {
                                    model.testMini?()
                                }
                            }
                        }
                    )
                }

                NativeGroup(VoiceBankText.pick("Permissions", "权限")) {
                    InfoRow(
                        title: VoiceBankText.pick("Required Permissions", "所需权限"),
                        subtitle: VoiceBankText.pick("Microphone, Accessibility, Input Monitoring, and Automation when prompted.", "麦克风、辅助功能、输入监控，以及系统提示时的自动化权限。"),
                        systemImage: "lock.shield",
                        trailing: {
                            Button(VoiceBankText.pick("Request", "请求")) {
                                model.requestPermissions?()
                            }
                        }
                    )
                    Divider()
                    InfoRow(
                        title: VoiceBankText.pick("Privacy Settings", "隐私设置"),
                        subtitle: VoiceBankText.pick("Open macOS privacy settings for Voice Bank.", "打开 macOS 隐私设置以检查 Voice Bank 权限。"),
                        systemImage: "gearshape",
                        trailing: {
                            Button(VoiceBankText.pick("Open", "打开")) {
                                model.openPrivacySettings?()
                            }
                        }
                    )
                }
            }
            .padding(VoiceBankUI.space28)
            .frame(maxWidth: 880, alignment: .leading)
        }
    }
}

private struct HistoryDashboardView: View {
    @ObservedObject var model: DashboardViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: VoiceBankUI.space16) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(VoiceBankText.pick("History", "历史记录"))
                        .font(.largeTitle.weight(.semibold))
                    Text(VoiceBankText.pick(
                        "\(model.stats.entryCount) entries · \(model.stats.todayChars) chars today · \(model.stats.totalChars) total chars",
                        "\(model.stats.entryCount) 条记录 · 今日 \(model.stats.todayChars) 字 · 累计 \(model.stats.totalChars) 字"
                    ))
                    .font(.callout)
                    .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    model.openHistoryFolder()
                } label: {
                    Label(VoiceBankText.pick("Open Folder", "打开文件夹"), systemImage: "folder")
                }
            }
            .padding([.horizontal, .top], VoiceBankUI.space28)
            .padding(.bottom, VoiceBankUI.space16)

            if model.historyEntries.isEmpty {
                ContentUnavailableView(
                    VoiceBankText.pick("No History Yet", "还没有历史记录"),
                    systemImage: "clock.arrow.circlepath",
                    description: Text(VoiceBankText.pick(
                        "Press Right Option to record. Successful transcriptions will appear here.",
                        "按右 Option 开始录音，识别成功后会出现在这里。"
                    ))
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(model.historyGroups, id: \.date) { group in
                        Section(group.title) {
                            ForEach(group.entries, id: \.id) { entry in
                                HistoryRow(entry: entry)
                            }
                        }
                    }
                }
                .listStyle(.inset)
            }
        }
    }
}

private struct HeaderView: View {
    @ObservedObject var model: DashboardViewModel

    var body: some View {
        HStack(spacing: VoiceBankUI.space16) {
            AppIconView()
            VStack(alignment: .leading, spacing: 5) {
                Text("Voice Bank")
                    .font(.largeTitle.weight(.semibold))
                Text(VoiceBankText.pick("Just Speak It", "说出来，自动写进去"))
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            StatusBadge(status: model.status)
        }
        .padding(VoiceBankUI.space20)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: VoiceBankUI.radius14, style: .continuous))
    }
}

private struct AppIconView: View {
    var body: some View {
        Group {
            if let image = NSImage(named: "VoiceBankIcon") {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                Image(systemName: "mic.fill")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.accentColor)
            }
        }
        .frame(width: 58, height: 58)
        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
    }
}

private struct StatusBadge: View {
    let status: VoiceBankStatus

    var body: some View {
        HStack(spacing: 7) {
            Circle()
                .fill(Color(nsColor: status.dotColor))
                .frame(width: 9, height: 9)
            Text(status.text)
                .font(.callout.weight(.medium))
                .lineLimit(1)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(.thinMaterial, in: Capsule())
    }
}

private struct StatTile: View {
    let title: String
    let value: Int
    let symbol: String

    var body: some View {
        HStack(spacing: VoiceBankUI.space14) {
            Image(systemName: symbol)
                .font(.title2.weight(.semibold))
                .foregroundStyle(Color.accentColor)
                .frame(width: 32)
            VStack(alignment: .leading, spacing: 3) {
                Text(value.formatted())
                    .font(.system(.largeTitle, design: .rounded).weight(.bold))
                    .monospacedDigit()
                Text(title)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(VoiceBankUI.space18)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: VoiceBankUI.radius12, style: .continuous))
    }
}

private struct NativeGroup<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: VoiceBankUI.space8) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.secondary)
                .padding(.horizontal, VoiceBankUI.space4)
            VStack(spacing: 0) {
                content
            }
            .padding(.vertical, 2)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: VoiceBankUI.radius12, style: .continuous))
        }
    }
}

private struct InfoRow<Trailing: View>: View {
    let title: String
    let subtitle: String?
    let systemImage: String
    @ViewBuilder let trailing: Trailing

    init(
        title: String,
        subtitle: String? = nil,
        systemImage: String,
        @ViewBuilder trailing: () -> Trailing = { EmptyView() }
    ) {
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
        self.trailing = trailing()
    }

    var body: some View {
        HStack(spacing: VoiceBankUI.space14) {
            Image(systemName: systemImage)
                .font(.body.weight(.medium))
                .foregroundStyle(Color.accentColor)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.body)
                if let subtitle {
                    Text(subtitle)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: VoiceBankUI.space16)
            trailing
        }
        .padding(.horizontal, VoiceBankUI.space16)
        .padding(.vertical, VoiceBankUI.space12)
    }
}

private struct PickerRow<Value: Hashable, TrailingContent: View>: View {
    let title: String
    let systemImage: String
    @Binding var selection: Value
    let values: [Value]
    let titleForValue: (Value) -> String
    let trailingContent: () -> TrailingContent

    init(
        title: String,
        systemImage: String,
        selection: Binding<Value>,
        values: [Value],
        titleForValue: @escaping (Value) -> String,
        trailingContent: @escaping () -> TrailingContent = { EmptyView() }
    ) {
        self.title = title
        self.systemImage = systemImage
        self._selection = selection
        self.values = values
        self.titleForValue = titleForValue
        self.trailingContent = trailingContent
    }

    var body: some View {
        InfoRow(title: title, systemImage: systemImage) {
            HStack(spacing: VoiceBankUI.space8) {
                trailingContent()
                Picker(title, selection: $selection) {
                    ForEach(values, id: \.self) { value in
                        Text(titleForValue(value)).tag(value)
                    }
                }
                .labelsHidden()
                .frame(width: 150)
            }
        }
    }
}

private struct KeyCapsule: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(.callout.monospaced().weight(.semibold))
            .padding(.horizontal, 11)
            .padding(.vertical, 5)
            .background(Color(nsColor: .controlBackgroundColor), in: Capsule())
    }
}

private struct HistoryRow: View {
    let entry: HistoryEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(entry.text)
                .font(.body)
                .lineLimit(6)
            Text(VoiceBankText.pick("\(entry.time) · \(entry.textChars) chars", "\(entry.time) · \(entry.textChars) 字"))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 7)
    }
}

enum VoiceBankUI {
    static let space4: CGFloat = 4
    static let space8: CGFloat = 8
    static let space12: CGFloat = 12
    static let space14: CGFloat = 14
    static let space16: CGFloat = 16
    static let space18: CGFloat = 18
    static let space20: CGFloat = 20
    static let space24: CGFloat = 24
    static let space28: CGFloat = 28
    static let radius12: CGFloat = 12
    static let radius14: CGFloat = 14
}
