import SwiftUI

struct LoopView: View {
    @StateObject private var audioEngine = AudioEngine()
    
    var body: some View {
        VStack(spacing: 20) {
            // Loop tracks display
            ScrollView {
                VStack(spacing: 16) {
                    ForEach(audioEngine.loops) { loop in
                        LoopTrackView(loop: loop, audioEngine: audioEngine)
                    }
                }
                .padding()
            }
            
            Spacer()
            
            // Recording controls
            VStack(spacing: 20) {
                // Main record button
                Button(action: {
                    audioEngine.toggleRecording()
                }) {
                    Circle()
                        .fill(audioEngine.isRecording ? .red : .blue.opacity(0.8))
                        .frame(width: 80, height: 80)
                        .overlay(
                            Circle()
                                .stroke(Color.white, lineWidth: 4)
                        )
                        .shadow(radius: 5)
                }
                
                // Global playback controls
                HStack(spacing: 40) {
                    Button(action: {
                        audioEngine.stopAllLoops()
                    }) {
                        Image(systemName: "stop.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(Color.blue.opacity(0.3))
                            .clipShape(Circle())
                    }
                    .disabled(audioEngine.loops.isEmpty)
                    
                    Button(action: {
                        if audioEngine.isPlaying {
                            audioEngine.stopAllLoops()
                        } else {
                            audioEngine.playAllLoops()
                        }
                    }) {
                        Image(systemName: audioEngine.isPlaying ? "pause.fill" : "play.fill")
                            .font(.title2)
                            .foregroundColor(audioEngine.loops.isEmpty ? .gray : .white)
                            .frame(width: 44, height: 44)
                            .background(Color.blue.opacity(audioEngine.loops.isEmpty ? 0.1 : 0.3))
                            .clipShape(Circle())
                    }
                    .disabled(audioEngine.loops.isEmpty)
                }
                
                // Port selection buttons
                HStack {
                    AudioPortButton(
                        isInput: true,
                        currentPort: audioEngine.currentInput,
                        availablePorts: audioEngine.availableInputs,
                        onSelect: { port in
                            audioEngine.changeAudioInput(to: port)
                        }
                    )
                    
                    Spacer()
                    
                    AudioPortButton(
                        isInput: false,
                        currentPort: audioEngine.currentOutput,
                        availablePorts: audioEngine.availableOutputs,
                        onSelect: { port in
                            audioEngine.changeAudioOutput(to: port)
                        }
                    )
                }
                .padding(.horizontal)
            }
            .padding(.bottom, 20)
        }
        .navigationTitle("Loop")
    }
} 