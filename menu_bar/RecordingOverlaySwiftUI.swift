import SwiftUI

final class RecordingOverlayModel: ObservableObject {
    @Published var state: RecordingOverlayState = .recording
    @Published var audioLevel: CGFloat = 0
    @Published var waveformLevels: [CGFloat] = Array(repeating: 0.08, count: 16)
    @Published var localizationRevision: Int = 0
    private var sampleIndex = 0

    func show(_ newState: RecordingOverlayState) {
        state = newState
        if newState != .recording {
            audioLevel = 0
            waveformLevels = Array(repeating: 0.08, count: waveformLevels.count)
        }
    }

    func updateAudioLevel(_ level: CGFloat) {
        let clamped = min(max(level, 0), 1)
        audioLevel = clamped
        guard state == .recording else {
            return
        }

        sampleIndex &+= 1
        let shaped = pow(clamped, 0.62)
        let pulse = CGFloat((sin(Double(sampleIndex) * 0.83) + 1) * 0.5)
        let micro = CGFloat((sin(Double(sampleIndex) * 1.71) + 1) * 0.5)
        let organic = min(max(shaped * (0.76 + pulse * 0.20 + micro * 0.08), 0), 1)
        waveformLevels.removeFirst()
        waveformLevels.append(max(organic, 0.08))
    }

    func refreshLocalizedText() {
        localizationRevision &+= 1
    }
}

struct RecordingOverlayView: View {
    @ObservedObject var model: RecordingOverlayModel

    var body: some View {
        HStack(spacing: 13) {
            ZStack {
                Circle()
                    .fill(style.tint.opacity(0.11))
                    .frame(width: 34, height: 34)
                Image(systemName: style.leadingSymbol)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(style.tint)
            }

            Group {
                switch model.state {
                case .recording:
                    WaveformView(levels: model.waveformLevels, color: style.tint)
                        .frame(width: 124, height: 32)
                case .processing:
                    ProgressView()
                        .controlSize(.small)
                        .frame(width: 124, height: 32)
                case .done, .canceled, .failed:
                    Color.clear
                        .frame(width: 124, height: 32)
                }
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(model.state.labelText)
                    .id(model.localizationRevision)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.primary)
                if let subtitle = style.subtitle {
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(minWidth: 84, alignment: .leading)
        }
        .padding(.horizontal, 18)
        .frame(width: 334, height: 66)
        .background(.regularMaterial, in: Capsule())
        .overlay {
            Capsule()
                .strokeBorder(Color(nsColor: .separatorColor).opacity(0.28), lineWidth: 0.8)
        }
    }

    private var style: RecordingOverlayStyle {
        RecordingOverlayStyle(state: model.state)
    }
}

private struct WaveformView: View {
    let levels: [CGFloat]
    let color: Color

    var body: some View {
        HStack(spacing: 4.5) {
            ForEach(levels.indices, id: \.self) { index in
                Capsule()
                    .fill(color)
                    .frame(width: 2.5, height: height(for: levels[index]))
                    .animation(.easeOut(duration: 0.11), value: levels[index])
            }
        }
        .frame(maxHeight: .infinity, alignment: .center)
    }

    private func height(for sample: CGFloat) -> CGFloat {
        let idle: CGFloat = 4
        let lift: CGFloat = 26
        return idle + lift * min(max(sample, 0), 1)
    }
}

private struct RecordingOverlayStyle {
    let state: RecordingOverlayState

    var tint: Color {
        switch state {
        case .recording:
            return .accentColor
        case .processing:
            return .accentColor
        case .done:
            return .green
        case .canceled:
            return .orange
        case .failed:
            return .red
        }
    }

    var leadingSymbol: String {
        switch state {
        case .recording:
            return "waveform"
        case .processing:
            return "waveform"
        case .done:
            return "checkmark.circle.fill"
        case .canceled:
            return "xmark.circle.fill"
        case .failed:
            return "exclamationmark.triangle.fill"
        }
    }

    var subtitle: String? {
        switch state {
        case .recording:
            return VoiceBankText.pick("Right Option to stop", "右 Option 结束")
        case .processing:
            return VoiceBankText.pick("Preparing text", "正在整理文本")
        case .done:
            return VoiceBankText.pick("Inserted at cursor", "已写入光标处")
        case .canceled:
            return nil
        case .failed:
            return VoiceBankText.pick("Check Mini or permissions", "检查 Mini 或权限")
        }
    }
}
