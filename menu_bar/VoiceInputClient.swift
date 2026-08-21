import AVFoundation
import Foundation

struct VoiceInputCompletion {
    let terminationStatus: Int32
    let output: String
}

enum VoiceInputClientError: LocalizedError {
    case alreadyRunning
    case invalidEndpoint
    case cannotCreateRecordingDirectory
    case cannotStartRecording
    case microphonePermissionDenied

    var errorDescription: String? {
        switch self {
        case .alreadyRunning:
            return VoiceBankText.pick("Voice input is already running.", "语音输入正在运行。")
        case .invalidEndpoint:
            return VoiceBankText.pick("The server address is invalid.", "服务地址无效。")
        case .cannotCreateRecordingDirectory:
            return VoiceBankText.pick("Could not create a secure recording folder.", "无法创建安全录音目录。")
        case .cannotStartRecording:
            return VoiceBankText.pick("Could not start microphone recording.", "无法启动麦克风录音。")
        case .microphonePermissionDenied:
            return VoiceBankText.pick("Microphone permission is not allowed.", "未允许麦克风权限。")
        }
    }
}

final class VoiceInputClient {
    private let endpointProvider: () -> String
    private let audioLevelService: AudioLevelService?
    private let meterQueue = DispatchQueue(label: "local.voicebank.native-meter")
    private let session: URLSession

    private var recorder: AVAudioRecorder?
    private var meterTimer: DispatchSourceTimer?
    private var uploadTask: URLSessionDataTask?
    private var completionHandler: ((VoiceInputCompletion) -> Void)?
    private var recordingDirectoryURL: URL?
    private var recordingFileURL: URL?
    private var activeEndpoint = ""
    private var active = false

    var isRunning: Bool {
        active
    }

    var isProcessRunning: Bool {
        uploadTask != nil
    }

    init(
        endpointProvider: @escaping () -> String,
        audioLevelService: AudioLevelService? = nil
    ) {
        self.endpointProvider = endpointProvider
        self.audioLevelService = audioLevelService

        self.session = VoiceBankConfig.makeURLSession()
    }

    func start(onCompletion: @escaping (VoiceInputCompletion) -> Void) throws {
        guard !active else {
            throw VoiceInputClientError.alreadyRunning
        }

        let endpoint = endpointProvider()
        guard let endpointURL = URL(string: endpoint),
              let scheme = endpointURL.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              endpointURL.host != nil else {
            throw VoiceInputClientError.invalidEndpoint
        }

        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .denied, .restricted:
            throw VoiceInputClientError.microphonePermissionDenied
        default:
            break
        }

        let manager = FileManager.default
        let directory = manager.temporaryDirectory
            .appendingPathComponent("voicebank-recording-\(UUID().uuidString)", isDirectory: true)
        do {
            try manager.createDirectory(
                at: directory,
                withIntermediateDirectories: false,
                attributes: [.posixPermissions: 0o700]
            )
        } catch {
            throw VoiceInputClientError.cannotCreateRecordingDirectory
        }

        let recordingURL = directory.appendingPathComponent("recording.wav")
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatLinearPCM),
            AVSampleRateKey: 16_000,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsFloatKey: false,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        do {
            let nextRecorder = try AVAudioRecorder(url: recordingURL, settings: settings)
            nextRecorder.isMeteringEnabled = true
            guard nextRecorder.prepareToRecord(), nextRecorder.record() else {
                try? manager.removeItem(at: directory)
                throw VoiceInputClientError.cannotStartRecording
            }

            recorder = nextRecorder
            completionHandler = onCompletion
            recordingDirectoryURL = directory
            recordingFileURL = recordingURL
            activeEndpoint = endpoint
            active = true
            startMetering()
        } catch let error as VoiceInputClientError {
            throw error
        } catch {
            try? manager.removeItem(at: directory)
            throw VoiceInputClientError.cannotStartRecording
        }
    }

    func finishRecording() -> Bool {
        guard active, let recorder, recorder.isRecording, let recordingFileURL else {
            return false
        }

        let recordedDuration = recorder.currentTime
        stopMetering()
        recorder.stop()
        self.recorder = nil
        audioLevelService?.reset()

        guard recordedDuration >= 0.35,
              let attributes = try? FileManager.default.attributesOfItem(atPath: recordingFileURL.path),
              let fileSize = attributes[.size] as? NSNumber,
              fileSize.intValue > 44 else {
            finish(status: 4, output: VoiceBankText.pick(
                "Recording failed: no usable audio was captured.",
                "录音失败：没有录到足够的有效音频。"
            ))
            return true
        }

        upload(recordingFileURL)
        return true
    }

    func terminate() {
        stopMetering()
        recorder?.stop()
        recorder = nil
        uploadTask?.cancel()
        uploadTask = nil
        active = false
        activeEndpoint = ""
        completionHandler = nil
        audioLevelService?.reset()
        removeTemporaryRecording()
    }

    func forceClear() {
        terminate()
    }

    private func startMetering() {
        stopMetering()
        let timer = DispatchSource.makeTimerSource(queue: meterQueue)
        timer.schedule(deadline: .now(), repeating: 0.06)
        timer.setEventHandler { [weak self] in
            guard let self, let recorder = self.recorder, recorder.isRecording else {
                return
            }
            recorder.updateMeters()
            let decibels = recorder.averagePower(forChannel: 0)
            let linear = pow(10.0, Double(decibels) / 20.0)
            self.audioLevelService?.consumeRawLevel(min(1.0, linear * 18.0))
        }
        meterTimer = timer
        timer.resume()
    }

    private func stopMetering() {
        meterTimer?.setEventHandler {}
        meterTimer?.cancel()
        meterTimer = nil
    }

    private func upload(_ fileURL: URL) {
        guard let endpointURL = URL(string: activeEndpoint) else {
            finish(status: 1, output: VoiceBankText.pick("Invalid server address.", "服务地址无效。"))
            return
        }

        do {
            let audioData = try Data(contentsOf: fileURL)
            let boundary = "VoiceBank-\(UUID().uuidString)"
            var body = Data()
            body.appendUTF8("--\(boundary)\r\n")
            body.appendUTF8("Content-Disposition: form-data; name=\"file\"; filename=\"recording.wav\"\r\n")
            body.appendUTF8("Content-Type: audio/wav\r\n\r\n")
            body.append(audioData)
            body.appendUTF8("\r\n--\(boundary)--\r\n")

            var request = URLRequest(url: endpointURL)
            request.httpMethod = "POST"
            request.timeoutInterval = 150
            request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            if let token = VoiceBankConfig.serverToken {
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            }
            request.httpBody = body

            let nextTask = session.dataTask(with: request) { [weak self] data, response, error in
                self?.handleUploadResponse(data: data, response: response, error: error)
            }
            uploadTask = nextTask
            nextTask.resume()
        } catch {
            finish(status: 1, output: VoiceBankText.pick(
                "Could not read the recording: \(error.localizedDescription)",
                "无法读取录音：\(error.localizedDescription)"
            ))
        }
    }

    private func handleUploadResponse(data: Data?, response: URLResponse?, error: Error?) {
        if let error {
            finish(status: 1, output: VoiceBankText.pick(
                "Server request failed: \(error.localizedDescription)",
                "服务请求失败：\(error.localizedDescription)"
            ))
            return
        }

        guard let http = response as? HTTPURLResponse else {
            finish(status: 1, output: VoiceBankText.pick("The server returned no HTTP response.", "服务端没有返回 HTTP 响应。"))
            return
        }
        guard (200..<300).contains(http.statusCode), let data else {
            let detail = data.flatMap { String(data: $0, encoding: .utf8) } ?? ""
            finish(status: 1, output: "HTTP \(http.statusCode): \(String(detail.prefix(400)))")
            return
        }

        do {
            guard let result = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                throw NativeVoiceInputError.invalidResponse
            }
            guard let text = Self.resultText(from: result), !text.isEmpty else {
                throw NativeVoiceInputError.missingText
            }

            try? HistoryStore().append(result: result, outputText: text, endpoint: activeEndpoint)

            let raw = result["raw"] as? String ?? ""
            var lines: [String] = []
            if !raw.isEmpty, raw != text {
                lines.append("原始文本: \(raw)")
            }
            lines.append("输出文本: \(text)")
            finish(status: 0, output: lines.joined(separator: "\n"))
        } catch {
            finish(status: 1, output: VoiceBankText.pick(
                "Could not parse the server response: \(error.localizedDescription)",
                "无法解析服务端返回结果：\(error.localizedDescription)"
            ))
        }
    }

    private func finish(status: Int32, output: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self else {
                return
            }
            let completion = self.completionHandler
            self.uploadTask = nil
            self.recorder = nil
            self.active = false
            self.activeEndpoint = ""
            self.completionHandler = nil
            self.audioLevelService?.reset()
            self.removeTemporaryRecording()
            completion?(VoiceInputCompletion(terminationStatus: status, output: output))
        }
    }

    private func removeTemporaryRecording() {
        if let recordingDirectoryURL {
            try? FileManager.default.removeItem(at: recordingDirectoryURL)
        }
        recordingDirectoryURL = nil
        recordingFileURL = nil
    }

    private static func resultText(from result: [String: Any]) -> String? {
        for key in ["polished", "polished_text", "text", "raw"] {
            if let value = result[key] as? String {
                let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    return trimmed
                }
            }
        }
        return nil
    }
}

private enum NativeVoiceInputError: LocalizedError {
    case invalidResponse
    case missingText

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return VoiceBankText.pick("Invalid JSON response.", "JSON 返回格式无效。")
        case .missingText:
            return VoiceBankText.pick("The response contained no transcript text.", "返回结果中没有转写文字。")
        }
    }
}

private extension Data {
    mutating func appendUTF8(_ text: String) {
        append(Data(text.utf8))
    }
}
