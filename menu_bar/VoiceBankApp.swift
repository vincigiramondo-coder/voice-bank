import AppKit

@main
struct VoiceBankApp {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        delegate.start()
        app.run()
    }
}
