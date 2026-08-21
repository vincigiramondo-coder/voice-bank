import AppKit

enum DashboardPage: String, CaseIterable, Hashable {
    case home
    case history

    var title: String {
        switch self {
        case .home:
            return VoiceBankText.pick("Home", "首页")
        case .history:
            return VoiceBankText.pick("History", "历史")
        }
    }

    var symbolName: String {
        switch self {
        case .home:
            return "house"
        case .history:
            return "clock.arrow.circlepath"
        }
    }
}

class RoundedView: NSView {
    var fillColor: NSColor
    var strokeColor: NSColor
    var radius: CGFloat

    init(fillColor: NSColor = .white, strokeColor: NSColor = lineColor, radius: CGFloat = 18) {
        self.fillColor = fillColor
        self.strokeColor = strokeColor
        self.radius = radius
        super.init(frame: .zero)
        wantsLayer = true
        translatesAutoresizingMaskIntoConstraints = false
    }

    required init?(coder: NSCoder) {
        self.fillColor = .white
        self.strokeColor = lineColor
        self.radius = 18
        super.init(coder: coder)
        wantsLayer = true
        translatesAutoresizingMaskIntoConstraints = false
    }

    override func layout() {
        super.layout()
        layer?.cornerRadius = radius
        layer?.backgroundColor = fillColor.cgColor
        layer?.borderColor = strokeColor.cgColor
        layer?.borderWidth = 1
    }
}

final class FlippedView: NSView {
    override var isFlipped: Bool {
        true
    }
}

final class StatCardView: RoundedView {
    init(symbolName: String, value: String, unit: String, caption: String) {
        super.init(fillColor: .white, strokeColor: lineColor, radius: 14)

        let icon = makeSymbol(symbolName, pointSize: 30, color: accentColor)
        let valueLabel = makeLabel(value, size: 34, weight: .bold)
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
        addSubview(row)

        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: 104),
            row.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 24),
            row.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -24),
            row.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

final class SettingRowView: NSView {
    init(title: String, subtitle: String? = nil, trailing: NSView? = nil) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = makeLabel(title, size: 16, weight: .medium)
        var labels: [NSView] = [titleLabel]
        if let subtitle {
            labels.append(makeLabel(subtitle, size: 13, color: mutedTextColor))
        }

        let labelStack = NSStackView(views: labels)
        labelStack.orientation = .vertical
        labelStack.spacing = 3
        labelStack.alignment = .leading
        labelStack.translatesAutoresizingMaskIntoConstraints = false

        let spacer = NSView()
        spacer.translatesAutoresizingMaskIntoConstraints = false

        let row = NSStackView()
        row.orientation = .horizontal
        row.spacing = 16
        row.alignment = .centerY
        row.translatesAutoresizingMaskIntoConstraints = false
        row.addArrangedSubview(labelStack)
        row.addArrangedSubview(spacer)
        if let trailing {
            row.addArrangedSubview(trailing)
        }
        addSubview(row)

        NSLayoutConstraint.activate([
            heightAnchor.constraint(greaterThanOrEqualToConstant: subtitle == nil ? 58 : 72),
            row.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 22),
            row.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -22),
            row.topAnchor.constraint(equalTo: topAnchor, constant: 10),
            row.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -10)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

final class PillView: RoundedView {
    init(_ text: String, fill: NSColor = NSColor(calibratedWhite: 0.91, alpha: 1), color: NSColor = textColor) {
        super.init(fillColor: fill, strokeColor: .clear, radius: 7)
        let label = makeLabel(text, size: 15, weight: .semibold, color: color, alignment: .center)
        label.font = .monospacedSystemFont(ofSize: 15, weight: .semibold)
        addSubview(label)
        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: 34),
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            label.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
