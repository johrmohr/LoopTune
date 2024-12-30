import Foundation
import AVFoundation

class AudioEngine: NSObject, ObservableObject {
    @Published var isRecording = false
    @Published var isPlaying = false
    @Published var loops: [AudioLoop] = []
    @Published var availableInputs: [AVAudioSessionPortDescription] = []
    @Published var availableOutputs: [AVAudioSessionPortDescription] = []
    @Published var currentInput: AVAudioSessionPortDescription?
    @Published var currentOutput: AVAudioSessionPortDescription?
    @Published var mutedLoops: Set<UUID> = []
    @Published var soloLoop: UUID?
    
    private var audioEngine: AVAudioEngine!
    private var recorder: AVAudioRecorder?
    private var players: [URL: AVAudioPlayer] = [:]
    private var currentRecordingURL: URL?
    private var masterLoopDuration: TimeInterval?
    private var recordingTimer: Timer?
    private var playerDelegates: [URL: PlayerDelegate] = [:]
    
    override init() {
        super.init()
        setupAudioSession()
        setupAudioEngine()
        
        // Add observer for route changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleRouteChange),
            name: AVAudioSession.routeChangeNotification,
            object: nil
        )
        
        // Initial port update
        updateAvailablePorts()
        
        print("Documents directory: \(getDocumentsDirectory().path)")
    }
    
    private func setupAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, options: [.defaultToSpeaker, .allowBluetooth, .mixWithOthers, .allowBluetoothA2DP, .allowAirPlay])
            try session.setActive(true)
            
            // Request microphone permission
            session.requestRecordPermission { [weak self] allowed in
                DispatchQueue.main.async {
                    if allowed {
                        print("Microphone permission granted")
                        self?.updateAvailablePorts()
                    } else {
                        print("Microphone permission denied")
                    }
                }
            }
        } catch {
            print("Failed to set up audio session: \(error)")
        }
    }
    
    private func setupAudioEngine() {
        audioEngine = AVAudioEngine()
    }
    
    private func getDocumentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    private func updateAvailablePorts() {
        let session = AVAudioSession.sharedInstance()
        
        // Update available inputs
        availableInputs = session.availableInputs ?? []
        
        // Update available outputs
        let currentRoute = session.currentRoute
        availableOutputs = currentRoute.outputs
        
        // Update current input/output
        currentInput = currentRoute.inputs.first
        currentOutput = currentRoute.outputs.first
        
        print("Available inputs: \(availableInputs.map { $0.portName })")
        print("Available outputs: \(availableOutputs.map { $0.portName })")
        print("Current input: \(currentInput?.portName ?? "none")")
        print("Current output: \(currentOutput?.portName ?? "none")")
    }
    
    @objc private func handleRouteChange(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else {
            return
        }
        
        print("Audio route changed: \(reason)")
        
        // Only update available ports, but maintain current selections if they're still valid
        let session = AVAudioSession.sharedInstance()
        availableInputs = session.availableInputs ?? []
        availableOutputs = session.currentRoute.outputs
        
        // Update current input/output only if they're no longer available
        let currentInputStillAvailable = availableInputs.contains { $0.portName == currentInput?.portName }
        let currentOutputStillAvailable = availableOutputs.contains { $0.portName == currentOutput?.portName }
        
        if !currentInputStillAvailable {
            currentInput = session.currentRoute.inputs.first
            print("Input changed to: \(currentInput?.portName ?? "none")")
        }
        
        if !currentOutputStillAvailable {
            currentOutput = session.currentRoute.outputs.first
            print("Output changed to: \(currentOutput?.portName ?? "none")")
        }
    }
    
    func changeAudioInput(to port: AVAudioSessionPortDescription) {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setActive(false)
            try session.setPreferredInput(port)
            try session.setActive(true)
            
            // Update current input after change
            currentInput = session.currentRoute.inputs.first
            print("Changed input to: \(port.portName)")
        } catch {
            print("Failed to change input: \(error.localizedDescription)")
        }
    }
    
    func changeAudioOutput(to port: AVAudioSessionPortDescription) {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setActive(false)
            
            // For output, we need to override the category
            let options: AVAudioSession.CategoryOptions = port.portType == .bluetoothA2DP ? [.allowBluetoothA2DP] : [.defaultToSpeaker]
            try session.setCategory(.playAndRecord, options: options)
            try session.setActive(true)
            
            // Update current output after change
            currentOutput = session.currentRoute.outputs.first
            print("Changed output to: \(port.portName)")
        } catch {
            print("Failed to change output: \(error.localizedDescription)")
        }
    }
    
    func startRecording() {
        // Ensure we're not already recording
        guard !isRecording else { return }
        
        // Ensure audio session is properly configured
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setActive(true)
        } catch {
            print("Failed to activate audio session: \(error)")
            return
        }
        
        // Create a unique filename for this recording
        let filename = "loop_\(Date().timeIntervalSince1970).m4a"
        currentRecordingURL = getDocumentsDirectory().appendingPathComponent(filename)
        
        guard let recordingURL = currentRecordingURL else {
            print("Failed to create recording URL")
            return
        }
        
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100.0,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
            AVEncoderBitRateKey: 128000
        ]
        
        do {
            // Remove any existing file at the URL
            if FileManager.default.fileExists(atPath: recordingURL.path) {
                try FileManager.default.removeItem(at: recordingURL)
            }
            
            recorder = try AVAudioRecorder(url: recordingURL, settings: settings)
            guard let recorder = recorder else {
                print("Failed to create recorder")
                return
            }
            
            recorder.delegate = self
            recorder.prepareToRecord()
            
            // If we have existing loops, play them all before starting the new recording
            if !loops.isEmpty {
                print("Playing all existing loops before recording...")
                loops.forEach { loop in
                    playLoop(loop)
                }
            }
            
            if recorder.record() {
                DispatchQueue.main.async {
                    self.isRecording = true
                }
                print("Successfully started recording to: \(recordingURL.path)")
                
                // If we have a master duration, set up a timer to stop recording
                if let masterDuration = masterLoopDuration {
                    print("Recording will stop after \(masterDuration) seconds")
                    recordingTimer = Timer.scheduledTimer(withTimeInterval: masterDuration, repeats: false) { [weak self] _ in
                        self?.stopRecording()
                    }
                }
            } else {
                print("Failed to start recording - recorder.record() returned false")
                stopAllLoops()
            }
        } catch {
            print("Failed to start recording: \(error.localizedDescription)")
            stopAllLoops()
        }
    }
    
    func stopRecording() {
        // Cancel any existing timer
        recordingTimer?.invalidate()
        recordingTimer = nil
        
        guard isRecording, let recorder = recorder else {
            print("No active recording to stop")
            return
        }
        
        print("Stopping recording...")
        recorder.stop()
        
        // Stop all playing loops when recording stops
        stopAllLoops()
        
        // Verify the recording
        if let url = currentRecordingURL, FileManager.default.fileExists(atPath: url.path) {
            do {
                let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
                let fileSize = attributes[.size] as? UInt64 ?? 0
                if fileSize > 0 {
                    // Try to create an audio player to verify the file is valid
                    do {
                        let testPlayer = try AVAudioPlayer(contentsOf: url)
                        if testPlayer.duration > 0 {
                            // If this is the first recording, set it as the master duration
                            if masterLoopDuration == nil {
                                masterLoopDuration = testPlayer.duration
                                print("Set master loop duration to: \(masterLoopDuration!) seconds")
                            }
                            
                            let newLoop = AudioLoop(url: url, duration: testPlayer.duration)
                            DispatchQueue.main.async {
                                self.loops.append(newLoop)
                                print("Added new loop to list. Total loops: \(self.loops.count)")
                            }
                            print("Successfully saved recording at: \(url.path)")
                        } else {
                            print("Recording file exists but has no duration")
                            try FileManager.default.removeItem(at: url)
                        }
                    } catch {
                        print("Recording file exists but is not valid audio: \(error)")
                        try FileManager.default.removeItem(at: url)
                    }
                } else {
                    print("Recording file is empty")
                    try FileManager.default.removeItem(at: url)
                }
            } catch {
                print("Error checking recording file: \(error.localizedDescription)")
            }
        }
        
        self.recorder = nil
        currentRecordingURL = nil
        
        DispatchQueue.main.async {
            self.isRecording = false
        }
    }
    
    func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }
    
    func playLoop(_ loop: AudioLoop, loopIndefinitely: Bool = false, completion: (() -> Void)? = nil) {
        do {
            if let existingPlayer = players[loop.url] {
                existingPlayer.play()
                print("Resumed existing player")
            } else {
                let player = try AVAudioPlayer(contentsOf: loop.url)
                player.numberOfLoops = loopIndefinitely ? -1 : 0
                player.volume = mutedLoops.contains(loop.id) ? 0 : loop.volume
                if let soloLoop = soloLoop, soloLoop != loop.id {
                    player.volume = 0
                }
                
                // Create and set delegate if not looping indefinitely
                if !loopIndefinitely {
                    let delegate = PlayerDelegate {
                        DispatchQueue.main.async {
                            completion?()
                        }
                    }
                    playerDelegates[loop.url] = delegate
                    player.delegate = delegate
                }
                
                player.prepareToPlay()
                if player.play() {
                    players[loop.url] = player
                    print("Started playing loop from: \(loop.url.path)")
                } else {
                    print("Failed to start playback")
                }
            }
        } catch {
            print("Failed to play loop: \(error.localizedDescription)")
        }
    }
    
    func stopLoop(_ loop: AudioLoop) {
        if let player = players[loop.url] {
            player.stop()
            players[loop.url] = nil
            playerDelegates[loop.url] = nil
            print("Stopped playing loop from: \(loop.url.path)")
        }
    }
    
    func setVolume(_ volume: Float, for loop: AudioLoop) {
        players[loop.url]?.volume = volume
    }
    
    func stopAllLoops() {
        players.values.forEach { $0.stop() }
        players.removeAll()
        DispatchQueue.main.async {
            self.isPlaying = false
        }
        print("Stopped all loops")
    }
    
    func playAllLoops() {
        guard let masterDuration = masterLoopDuration else {
            print("No master duration set")
            return
        }
        
        loops.forEach { loop in
            playLoop(loop, loopIndefinitely: true)
        }
        
        isPlaying = true
        print("Playing all loops continuously")
    }
    
    func deleteLoop(_ loop: AudioLoop) {
        // Stop the loop if it's playing
        stopLoop(loop)
        
        // Remove the file
        do {
            try FileManager.default.removeItem(at: loop.url)
            print("Deleted loop file at: \(loop.url.path)")
        } catch {
            print("Failed to delete loop file: \(error.localizedDescription)")
        }
        
        // Remove from loops array
        DispatchQueue.main.async {
            self.loops.removeAll { $0.id == loop.id }
            print("Removed loop from list. Total loops: \(self.loops.count)")
            
            // Reset master duration if all loops are deleted
            if self.loops.isEmpty {
                self.masterLoopDuration = nil
                print("Reset master loop duration")
            }
        }
    }
    
    func muteLoop(_ loop: AudioLoop) {
        if mutedLoops.contains(loop.id) {
            mutedLoops.remove(loop.id)
            if let player = players[loop.url] {
                player.volume = loop.volume
            }
        } else {
            mutedLoops.insert(loop.id)
            players[loop.url]?.volume = 0
        }
    }
    
    func soloLoop(_ loop: AudioLoop) {
        if soloLoop == loop.id {
            // Unsolo
            soloLoop = nil
            // Restore volumes based on mute status
            for (url, player) in players {
                if let loopId = loops.first(where: { $0.url == url })?.id {
                    player.volume = mutedLoops.contains(loopId) ? 0 : loops.first(where: { $0.url == url })?.volume ?? 1.0
                }
            }
        } else {
            // Solo this loop
            soloLoop = loop.id
            // Mute all other loops
            for (url, player) in players {
                if let loopId = loops.first(where: { $0.url == url })?.id {
                    player.volume = loopId == loop.id ? (loops.first(where: { $0.url == url })?.volume ?? 1.0) : 0
                }
            }
        }
    }
}

// MARK: - AVAudioRecorderDelegate
extension AudioEngine: AVAudioRecorderDelegate {
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        print("Recording finished - success: \(flag)")
        if !flag {
            // Clean up failed recording
            if let url = currentRecordingURL {
                try? FileManager.default.removeItem(at: url)
            }
        }
    }
    
    func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        if let error = error {
            print("Recording encode error: \(error.localizedDescription)")
        }
    }
}

struct AudioLoop: Identifiable {
    let id = UUID()
    let url: URL
    let duration: TimeInterval
    var isPlaying = false
    var volume: Float = 1.0
}

class PlayerDelegate: NSObject, AVAudioPlayerDelegate {
    private let completion: () -> Void
    
    init(completion: @escaping () -> Void) {
        self.completion = completion
        super.init()
    }
    
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        if flag {
            completion()
        }
    }
} 
