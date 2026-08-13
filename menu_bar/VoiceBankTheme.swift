import AppKit

let accentColor = NSColor(calibratedRed: 0.29, green: 0.49, blue: 0.93, alpha: 1)
let textColor = NSColor(calibratedWhite: 0.13, alpha: 1)
let mutedTextColor = NSColor(calibratedWhite: 0.52, alpha: 1)
let lineColor = NSColor(calibratedWhite: 0.88, alpha: 1)
let dashboardBackgroundColor = NSColor(calibratedWhite: 0.985, alpha: 1)

func makeLabel(
    _ text: String,
    size: CGFloat,
    weight: NSFont.Weight = .regular,
    color: NSColor = textColor,
    alignment: NSTextAlignment = .left
) -> NSTextField {
    let label = NSTextField(labelWithString: text)
    label.font = .systemFont(ofSize: size, weight: weight)
    label.textColor = color
    label.alignment = alignment
    label.lineBreakMode = .byTruncatingTail
    label.translatesAutoresizingMaskIntoConstraints = false
    return label
}

func makeSymbol(_ name: String, pointSize: CGFloat, color: NSColor = accentColor) -> NSImageView {
    let image = NSImage(systemSymbolName: name, accessibilityDescription: nil)
    let imageView = NSImageView(image: image ?? NSImage())
    imageView.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: pointSize, weight: .semibold)
    imageView.contentTintColor = color
    imageView.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
        imageView.widthAnchor.constraint(equalToConstant: pointSize + 4),
        imageView.heightAnchor.constraint(equalToConstant: pointSize + 4)
    ])
    return imageView
}
