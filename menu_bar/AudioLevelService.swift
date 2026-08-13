import Foundation

final class AudioLevelService {
    private let lock = NSLock()
    private let minEmitInterval: TimeInterval
    private var smoothedLevel: Double = 0
    private var lastEmit = Date.distantPast

    var onLevel: ((Double) -> Void)?

    init(minEmitInterval: TimeInterval = 1.0 / 30.0) {
        self.minEmitInterval = minEmitInterval
    }

    func consumeRawLevel(_ rawLevel: Double) {
        guard let level = process(rawLevel) else {
            return
        }
        DispatchQueue.main.async { [weak self] in
            self?.onLevel?(level)
        }
    }

    func reset() {
        lock.lock()
        smoothedLevel = 0
        lastEmit = Date.distantPast
        lock.unlock()

        DispatchQueue.main.async { [weak self] in
            self?.onLevel?(0)
        }
    }

    private func process(_ rawLevel: Double) -> Double? {
        let clamped = min(max(rawLevel, 0), 1)
        lock.lock()
        defer { lock.unlock() }

        smoothedLevel = smoothedLevel * 0.65 + clamped * 0.35
        let now = Date()
        guard now.timeIntervalSince(lastEmit) >= minEmitInterval else {
            return nil
        }
        lastEmit = now
        return smoothedLevel
    }
}
