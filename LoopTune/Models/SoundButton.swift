import Foundation
import AVFoundation

struct SoundButton: Identifiable {
    let id = UUID()
    var soundURL: URL?
    var player: AVAudioPlayer?
    var title: String
    
    init(title: String = "Empty") {
        self.title = title
    }
}

class SoundboardEngine: NSObject, ObservableObject {
    @Published var buttons: [SoundButton]
    @Published var isEditMode = false
    @Published var isRecording = false
    @Published var currentRecordingIndex: Int?
    
    private let fileManager = FileManager.default
    private var recorder: AVAudioRecorder?
    private var recordingTimer: Timer?
    
    override init() {
        self.buttons = (0..<8).map { _ in SoundButton() }
        super.init()
    }
    
    func startRecording(for index: Int) {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, options: [.defaultToSpeaker, .allowBluetooth, .mixWithOthers])
            try session.setActive(true)
            
            let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let audioFilename = documentsDirectory.appendingPathComponent("\(UUID().uuidString).m4a")
            
            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 44100.0,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ]
            
            recorder = try AVAudioRecorder(url: audioFilename, settings: settings)
            recorder?.delegate = self
            recorder?.record()
            
            DispatchQueue.main.async {
                self.currentRecordingIndex = index
                self.isRecording = true
            }
            
            // Stop recording after 5 seconds
            recordingTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: false) { [weak self] _ in
                self?.stopRecording()
            }
            
        } catch {
            print("Failed to start recording: \(error)")
        }
    }
    
    func stopRecording() {
        recordingTimer?.invalidate()
        recordingTimer = nil
        
        guard let recorder = recorder else { return }
        
        let url = recorder.url
        recorder.stop()
        self.recorder = nil
        
        // Create player from the recording
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.prepareToPlay()
            
            if let index = currentRecordingIndex {
                DispatchQueue.main.async {
                    var button = self.buttons[index]
                    button.soundURL = url
                    button.player = player
                    button.title = "Recording \(index + 1)"
                    self.buttons[index] = button
                    self.currentRecordingIndex = nil
                    self.isRecording = false
                }
            }
        } catch {
            print("Failed to create player from recording: \(error)")
            try? FileManager.default.removeItem(at: url)
        }
    }
    
    func assignSound(at index: Int, url: URL) {
        // Start accessing the security-scoped resource
        guard url.startAccessingSecurityScopedResource() else {
            print("Failed to access security scoped resource")
            return
        }
        
        defer {
            url.stopAccessingSecurityScopedResource()
        }
        
        do {
            // Get documents directory
            let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
            
            // Create a unique filename using UUID to prevent conflicts
            let uniqueFilename = "\(UUID().uuidString)_\(url.lastPathComponent)"
            let localURL = documentsDirectory.appendingPathComponent(uniqueFilename)
            
            // Remove any existing file
            if fileManager.fileExists(atPath: localURL.path) {
                try fileManager.removeItem(at: localURL)
            }
            
            // Copy the file
            try fileManager.copyItem(at: url, to: localURL)
            print("File copied successfully to: \(localURL.path)")
            
            // Create the audio player
            let player = try AVAudioPlayer(contentsOf: localURL)
            player.prepareToPlay()
            
            DispatchQueue.main.async {
                var button = self.buttons[index]
                button.soundURL = localURL
                button.player = player
                button.title = url.lastPathComponent // Use original filename for display
                self.buttons[index] = button
                print("Successfully added sound: \(url.lastPathComponent)")
            }
        } catch {
            print("Error setting up sound: \(error.localizedDescription)")
            if let nsError = error as NSError? {
                print("Detailed error: \(nsError.debugDescription)")
                print("Error domain: \(nsError.domain)")
                print("Error code: \(nsError.code)")
                print("Error user info: \(nsError.userInfo)")
            }
        }
    }
    
    func playSound(at index: Int) {
        guard !isEditMode, let player = buttons[index].player else { return }
        
        // Stop and reset if already playing
        player.stop()
        player.currentTime = 0
        
        do {
            try AVAudioSession.sharedInstance().setActive(true)
            player.play()
            print("Playing sound at index: \(index)")
        } catch {
            print("Failed to play sound: \(error)")
        }
    }
    
    func removeSound(at index: Int) {
        if let url = buttons[index].soundURL {
            do {
                try FileManager.default.removeItem(at: url)
                print("Removed sound file at: \(url.path)")
            } catch {
                print("Failed to remove sound file: \(error)")
            }
        }
        
        DispatchQueue.main.async {
            self.buttons[index] = SoundButton()
        }
    }
}

extension SoundboardEngine: AVAudioRecorderDelegate {
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        if !flag {
            print("Recording failed")
            try? FileManager.default.removeItem(at: recorder.url)
            DispatchQueue.main.async {
                self.currentRecordingIndex = nil
                self.isRecording = false
            }
        }
    }
    
    func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        if let error = error {
            print("Recording encode error: \(error)")
            DispatchQueue.main.async {
                self.currentRecordingIndex = nil
                self.isRecording = false
            }
        }
    }
} 