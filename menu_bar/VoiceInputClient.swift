import Foundation

struct VoiceInputCompletion {
    let terminationStatus: Int32
    let output: String
}

enum VoiceInputClientError: Error {
    case alreadyRunning
}

final class VoiceInputClient {
    private let projectDir: String
    private let endpoint: String
    private let audioLevelService: AudioLevelService?

    private var process: Process?
    private var inputPipe: Pipe?
    private var outputPipe: Pipe?
    private var outputBuffer = Data()
    private var pendingOutputLine = ""
    private let outputQueue = DispatchQueue(label: "local.voicebank.voiceinput.output")

    var isRunning: Bool {
        process != nil
    }

    var isProcessRunning: Bool {
        process?.isRunning ?? false
    }

    init(
        projectDir: String,
        endpoint: String,
        audioLevelService: AudioLevelService? = nil
    ) {
        self.projectDir = projectDir
        self.endpoint = endpoint
        self.audioLevelService = audioLevelService
    }

    func start(onCompletion: @escaping (VoiceInputCompletion) -> Void) throws {
        guard process == nil else {
            throw VoiceInputClientError.alreadyRunning
        }

        let python = "\(projectDir)/.venv/bin/python"
        let client = "\(projectDir)/air_voice_client.py"
        let nextProcess = Process()
        nextProcess.executableURL = URL(fileURLWithPath: python)
        nextProcess.arguments = [client, "--no-paste"]
        nextProcess.currentDirectoryURL = URL(fileURLWithPath: projectDir)
        var childEnvironment = [
            "VOICE_INPUT_SERVER_URL": endpoint,
            "VOICE_INPUT_TIMEOUT_SECONDS": "150",
            "VOICE_BANK_SAVE_LOCAL_HISTORY": VoiceBankPreferences.saveLocalHistory ? "1" : "0",
            "VOICE_BANK_HISTORY_RETENTION_DAYS": "\(VoiceBankPreferences.historyRetentionDays)"
        ]
        if let serverToken = VoiceBankConfig.serverToken {
            childEnvironment["VOICE_INPUT_SERVER_TOKEN"] = serverToken
        }
        nextProcess.environment = ProcessInfo.processInfo.environment.merging(childEnvironment) { _, new in new }

        let nextInputPipe = Pipe()
        let nextOutputPipe = Pipe()
        nextProcess.standardInput = nextInputPipe
        nextProcess.standardOutput = nextOutputPipe
        nextProcess.standardError = nextOutputPipe

        process = nextProcess
        inputPipe = nextInputPipe
        outputPipe = nextOutputPipe
        outputQueue.sync {
            outputBuffer = Data()
            pendingOutputLine = ""
        }

        nextOutputPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else {
                return
            }
            self?.handleOutputData(data)
        }

        nextProcess.terminationHandler = { [weak self] finishedProcess in
            let output = self?.finishAndReadOutput() ?? ""
            let completion = VoiceInputCompletion(
                terminationStatus: finishedProcess.terminationStatus,
                output: output
            )
            DispatchQueue.main.async {
                onCompletion(completion)
            }
        }

        do {
            try nextProcess.run()
            nextInputPipe.fileHandleForWriting.write(Data("\n".utf8))
        } catch {
            cleanup()
            throw error
        }
    }

    func finishRecording() -> Bool {
        guard let inputPipe else {
            return false
        }
        audioLevelService?.reset()
        inputPipe.fileHandleForWriting.write(Data("\n".utf8))
        inputPipe.fileHandleForWriting.closeFile()
        self.inputPipe = nil
        return true
    }

    func terminate() {
        audioLevelService?.reset()
        process?.terminate()
    }

    func forceClear() {
        cleanup()
    }

    private func handleOutputData(_ data: Data) {
        outputQueue.async { [weak self] in
            guard let self else {
                return
            }
            self.appendOutputData(data)
        }
    }

    private func appendOutputData(_ data: Data) {
        outputBuffer.append(data)
        guard let text = String(data: data, encoding: .utf8) else {
            return
        }
        handleOutputText(text)
    }

    private func handleOutputText(_ text: String) {
        pendingOutputLine += text
        var lines = pendingOutputLine.components(separatedBy: "\n")
        pendingOutputLine = lines.removeLast()
        for line in lines {
            handleOutputLine(line)
        }
    }

    private func handleOutputLine(_ line: String) {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("VB_LEVEL ") else {
            return
        }
        let valueText = trimmed.dropFirst("VB_LEVEL ".count)
        guard let level = Double(valueText) else {
            return
        }
        audioLevelService?.consumeRawLevel(level)
    }

    private func finishAndReadOutput() -> String {
        let outputReader = outputPipe?.fileHandleForReading
        outputReader?.readabilityHandler = nil
        let remainingData = outputReader?.readDataToEndOfFile() ?? Data()
        let output = outputQueue.sync { () -> String in
            if !remainingData.isEmpty {
                appendOutputData(remainingData)
            }
            let output = String(data: outputBuffer, encoding: .utf8) ?? ""
            outputBuffer = Data()
            pendingOutputLine = ""
            return output
        }
        outputPipe = nil
        process = nil
        inputPipe = nil
        audioLevelService?.reset()
        return output
    }

    private func cleanup() {
        outputPipe?.fileHandleForReading.readabilityHandler = nil
        outputQueue.sync {
            outputBuffer = Data()
            pendingOutputLine = ""
        }
        process = nil
        inputPipe = nil
        outputPipe = nil
        audioLevelService?.reset()
    }
}
