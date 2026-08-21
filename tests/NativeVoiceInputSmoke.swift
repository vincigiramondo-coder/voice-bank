import Foundation

@main
struct NativeVoiceInputSmoke {
    static func main() {
        let client = VoiceInputClient(endpointProvider: { VoiceBankConfig.endpoint })

        do {
            try client.start { completion in
                print(completion.output)
                if completion.terminationStatus == 0, completion.output.contains("输出文本:") {
                    print("NativeVoiceInputSmoke OK")
                    exit(0)
                }
                fputs("NativeVoiceInputSmoke failed with status \(completion.terminationStatus)\n", stderr)
                exit(1)
            }
        } catch {
            fputs("NativeVoiceInputSmoke could not start: \(error.localizedDescription)\n", stderr)
            exit(1)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            let speaker = Process()
            speaker.executableURL = URL(fileURLWithPath: "/usr/bin/say")
            speaker.arguments = ["-v", "Ting-Ting", "Voice Bank native client smoke test"]
            try? speaker.run()
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 3.2) {
            if !client.finishRecording() {
                fputs("NativeVoiceInputSmoke could not finish recording\n", stderr)
                exit(1)
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 175) {
            client.terminate()
            fputs("NativeVoiceInputSmoke timed out\n", stderr)
            exit(1)
        }

        RunLoop.main.run()
    }
}
