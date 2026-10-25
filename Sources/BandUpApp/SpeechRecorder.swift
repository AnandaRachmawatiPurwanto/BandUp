import AVFoundation
import Speech

/// Records the microphone and transcribes it live, on the Mac when possible.
@MainActor
@Observable
final class SpeechRecorder {
    private(set) var transcript = ""
    private(set) var isRecording = false
    private(set) var startedAt: Date?
    var errorText: String?

    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private let engine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    /// Text from earlier recognition segments, kept when the recognizer restarts.
    private var committed = ""

    func start() async {
        errorText = nil
        guard await Self.authorize() else {
            errorText = "BandUp needs microphone and speech recognition access. Allow it in System Settings → Privacy & Security."
            return
        }
        guard let recognizer, recognizer.isAvailable else {
            errorText = "English speech recognition isn't available on this Mac."
            return
        }

        transcript = ""
        committed = ""
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.addsPunctuation = true
        if recognizer.supportsOnDeviceRecognition { request.requiresOnDeviceRecognition = true }
        self.request = request

        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            request.append(buffer)
        }

        task = recognizer.recognitionTask(with: request) { [weak self] result, error in
            let text = result?.bestTranscription.formattedString
            let isFinal = result?.isFinal ?? false
            Task { @MainActor in
                guard let self else { return }
                if let text { self.transcript = [self.committed, text].filter { !$0.isEmpty }.joined(separator: " ") }
                if isFinal { self.committed = self.transcript }
                if error != nil, self.isRecording, self.transcript.isEmpty {
                    self.errorText = "Didn't catch that. Check your microphone and try again."
                }
            }
        }

        do {
            engine.prepare()
            try engine.start()
            isRecording = true
            startedAt = .now
        } catch {
            errorText = "Couldn't start the microphone: \(error.localizedDescription)"
            cleanUp()
        }
    }

    func stop() {
        guard isRecording else { return }
        isRecording = false
        engine.stop()
        engine.inputNode.removeTap(onBus: 0)
        // Ending the audio (rather than cancelling) lets the recognizer deliver its last words.
        request?.endAudio()
        request = nil
    }

    private func cleanUp() {
        engine.stop()
        engine.inputNode.removeTap(onBus: 0)
        task?.cancel()
        request = nil
        task = nil
    }

    private static func authorize() async -> Bool {
        let speech = await withCheckedContinuation { cont in
            SFSpeechRecognizer.requestAuthorization { cont.resume(returning: $0 == .authorized) }
        }
        let mic = await AVCaptureDevice.requestAccess(for: .audio)
        return speech && mic
    }
}
