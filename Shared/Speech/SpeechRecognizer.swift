import Speech
import AVFoundation

/// Reusable speech recognizer.  Call `startListening()` / `stopListening()`.
/// When `continuous == true` it automatically restarts after each final result
/// so it keeps accumulating segments (used by LiveListenView).
@MainActor
public final class SpeechRecognizer: ObservableObject {

    @Published public private(set) var transcript: String = ""
    @Published public private(set) var isListening: Bool = false
    @Published public private(set) var errorMessage: String?

    private nonisolated(unsafe) var audioEngine = AVAudioEngine()
    private nonisolated(unsafe) var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    /// Accumulated transcript segments from previous recognition sessions (continuous mode).
    private var accumulatedTranscript: String = ""

    private let recognizer: SFSpeechRecognizer?
    public let continuous: Bool

    public init(continuous: Bool = false) {
        self.continuous = continuous
        self.recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    }

    // MARK: - Public API

    public func startListening() async {
        errorMessage = nil
        transcript = ""
        accumulatedTranscript = ""

        guard await checkPermissions() else {
            errorMessage = "Enable Microphone and Speech Recognition in Settings → Privacy."
            return
        }
        startSession()
    }

    public func stopListening() {
        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.stop()
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
        isListening = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    // MARK: - Permissions

    private func checkPermissions() async -> Bool {
        let micGranted = await withCheckedContinuation { (cont: CheckedContinuation<Bool, Never>) in
            AVAudioApplication.requestRecordPermission { granted in cont.resume(returning: granted) }
        }
        guard micGranted else { return false }

        return await withCheckedContinuation { (cont: CheckedContinuation<Bool, Never>) in
            SFSpeechRecognizer.requestAuthorization { status in
                cont.resume(returning: status == .authorized)
            }
        }
    }

    // MARK: - Session management

    private func startSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .measurement, options: .duckOthers)
            try session.setActive(true, options: .notifyOthersOnDeactivation)

            recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
            recognitionRequest?.shouldReportPartialResults = true

            let inputNode = audioEngine.inputNode
            inputNode.removeTap(onBus: 0)
            let format = inputNode.outputFormat(forBus: 0)

            // Capture request locally so closure doesn't need @MainActor access
            guard let req = recognitionRequest else { return }
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
                req.append(buffer)
            }

            audioEngine.prepare()
            try audioEngine.start()
            isListening = true

            guard let recognizer, recognizer.isAvailable else {
                errorMessage = "Speech recognition is not available on this device."
                stopListening()
                return
            }

            recognitionTask = recognizer.recognitionTask(with: req) { [weak self] result, error in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    if let result {
                        let segment = result.bestTranscription.formattedString
                        if self.continuous && !self.accumulatedTranscript.isEmpty {
                            self.transcript = self.accumulatedTranscript + " " + segment
                        } else {
                            self.transcript = segment
                        }
                    }
                    if error != nil || result?.isFinal == true {
                        if self.continuous && self.isListening {
                            // Save completed segment before restarting
                            self.accumulatedTranscript = self.transcript
                            self.stopListening()
                            self.startSession()
                        } else {
                            self.stopListening()
                        }
                    }
                }
            }
        } catch {
            errorMessage = error.localizedDescription
            stopListening()
        }
    }
}
