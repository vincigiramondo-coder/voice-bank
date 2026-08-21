import Foundation

enum RecordingState {
    case idle
    case recording
    case processing
}

struct RecordingCoordinatorCallbacks {
    let setStatus: (VoiceBankStatus) -> Void
    let setVoiceMenuTitle: (String) -> Void
    let showRecording: () -> Void
    let showProcessing: () -> Void
    let showDone: () -> Void
    let showCanceled: () -> Void
    let showFailed: () -> Void
    let hideOverlay: () -> Void
    let refreshHistory: () -> Void
    let refreshPermissions: () -> Void
}

final class RecordingCoordinator {
    private let voiceInputClient: VoiceInputClient
    private let pasteService: PasteService
    private let callbacks: RecordingCoordinatorCallbacks
    private var state: RecordingState = .idle
    private var processingWatchdog: DispatchWorkItem?

    init(
        voiceInputClient: VoiceInputClient,
        pasteService: PasteService,
        callbacks: RecordingCoordinatorCallbacks
    ) {
        self.voiceInputClient = voiceInputClient
        self.pasteService = pasteService
        self.callbacks = callbacks
    }

    func toggle() {
        if !voiceInputClient.isRunning {
            start()
        } else if state == .recording {
            stop()
        } else {
            callbacks.setStatus(.stillProcessing)
        }
    }

    func cancel() {
        processingWatchdog?.cancel()
        processingWatchdog = nil
        guard voiceInputClient.isRunning else {
            state = .idle
            callbacks.setStatus(.idle)
            callbacks.hideOverlay()
            return
        }
        voiceInputClient.terminate()
        state = .idle
        updateVoiceMenuTitle()
        callbacks.setStatus(.canceled)
        callbacks.showCanceled()
    }

    func terminateForQuit() {
        processingWatchdog?.cancel()
        processingWatchdog = nil
        voiceInputClient.terminate()
        state = .idle
    }

    func refreshLocalizedDisplay() {
        updateVoiceMenuTitle()
    }

    private func start() {
        guard !voiceInputClient.isRunning else {
            callbacks.setStatus(state == .recording ? .alreadyRecording : .stillProcessing)
            return
        }

        do {
            try voiceInputClient.start { [weak self] completion in
                self?.handleCompletion(completion)
            }
            state = .recording
            callbacks.setStatus(.recording)
            callbacks.showRecording()
            updateVoiceMenuTitle()
        } catch {
            state = .idle
            updateVoiceMenuTitle()
            callbacks.setStatus(.launchFailed(error.localizedDescription))
            callbacks.hideOverlay()
        }
    }

    private func stop() {
        guard state == .recording, voiceInputClient.finishRecording() else {
            callbacks.setStatus(.stillProcessing)
            return
        }

        state = .processing
        callbacks.setStatus(.processing)
        callbacks.showProcessing()
        updateVoiceMenuTitle()
        startProcessingWatchdog()
    }

    private func handleCompletion(_ completion: VoiceInputCompletion) {
        processingWatchdog?.cancel()
        processingWatchdog = nil
        state = .idle
        updateVoiceMenuTitle()

        if completion.terminationStatus == 0 {
            let pasteResult = pasteService.pasteRecognizedText(from: completion.output) {
                callbacks.refreshPermissions()
            }
            callbacks.setStatus(pasteResult.status)
            callbacks.showDone()
            callbacks.refreshHistory()
        } else if completion.terminationStatus == 15 {
            callbacks.setStatus(.canceled)
            callbacks.showCanceled()
        } else {
            let summary = completion.output.split(separator: "\n").last.map(String.init) ?? "Exit \(completion.terminationStatus)"
            callbacks.setStatus(.failed(summary))
            callbacks.showFailed()
        }
    }

    private func startProcessingWatchdog() {
        processingWatchdog?.cancel()
        let watchdog = DispatchWorkItem { [weak self] in
            guard let self, self.voiceInputClient.isProcessRunning, self.state != .recording else {
                return
            }
            self.voiceInputClient.terminate()
            self.processingWatchdog = nil
            self.state = .idle
            self.updateVoiceMenuTitle()
            self.callbacks.setStatus(.timedOut)
            self.callbacks.hideOverlay()
        }
        processingWatchdog = watchdog
        DispatchQueue.main.asyncAfter(deadline: .now() + 170, execute: watchdog)
    }

    private func updateVoiceMenuTitle() {
        callbacks.setVoiceMenuTitle(voiceMenuState.title)
    }

    private var voiceMenuState: VoiceBankVoiceMenuState {
        switch state {
        case .idle:
            return .ready
        case .recording:
            return .recording
        case .processing:
            return .processing
        }
    }
}
