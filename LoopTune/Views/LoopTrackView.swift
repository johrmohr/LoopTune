import SwiftUI

struct LoopTrackView: View {
    let loop: AudioLoop
    let audioEngine: AudioEngine
    @State private var volume: Float
    @State private var isPlaying: Bool = false
    
    var isMuted: Bool {
        audioEngine.mutedLoops.contains(loop.id)
    }
    
    var isSolo: Bool {
        audioEngine.soloLoop == loop.id
    }
    
    init(loop: AudioLoop, audioEngine: AudioEngine) {
        self.loop = loop
        self.audioEngine = audioEngine
        self._volume = State(initialValue: loop.volume)
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Play/Pause Button
            Button(action: {
                if isPlaying {
                    audioEngine.stopLoop(loop)
                } else {
                    audioEngine.playLoop(loop, loopIndefinitely: false) {
                        // This will be called when the loop finishes playing
                        isPlaying = false
                    }
                }
                isPlaying.toggle()
            }) {
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .font(.title2)
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(Color.blue.opacity(0.3))
                    .clipShape(Circle())
            }
            
            // Volume slider
            Slider(value: Binding(
                get: { volume },
                set: { newValue in
                    volume = newValue
                    audioEngine.setVolume(newValue, for: loop)
                }
            ), in: 0...1)
            .tint(.blue)
            
            // Mute button
            Button(action: {
                audioEngine.muteLoop(loop)
            }) {
                Image(systemName: isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                    .font(.title3)
                    .foregroundColor(isMuted ? .red.opacity(0.8) : .white)
                    .frame(width: 44, height: 44)
                    .background(Color.blue.opacity(0.3))
                    .clipShape(Circle())
            }
            
            // Solo button
            Button(action: {
                audioEngine.soloLoop(loop)
            }) {
                Image(systemName: "headphones")
                    .font(.title3)
                    .foregroundColor(isSolo ? .yellow : .white)
                    .frame(width: 44, height: 44)
                    .background(Color.blue.opacity(0.3))
                    .clipShape(Circle())
            }
            
            // Delete button
            Button(action: {
                audioEngine.deleteLoop(loop)
            }) {
                Image(systemName: "trash.fill")
                    .font(.title3)
                    .foregroundColor(.red.opacity(0.8))
                    .frame(width: 44, height: 44)
                    .background(Color.red.opacity(0.1))
                    .clipShape(Circle())
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
} 