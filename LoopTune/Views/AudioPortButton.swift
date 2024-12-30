import SwiftUI
import AVFAudio

struct AudioPortButton: View {
    let isInput: Bool
    let currentPort: AVAudioSessionPortDescription?
    let availablePorts: [AVAudioSessionPortDescription]
    let onSelect: (AVAudioSessionPortDescription) -> Void
    
    var body: some View {
        Menu {
            ForEach(availablePorts, id: \.portName) { port in
                Button(action: {
                    onSelect(port)
                }) {
                    HStack {
                        Text(port.portName)
                        if port.portName == currentPort?.portName {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack {
                Label(
                    isInput ? "Input" : "Output",
                    systemImage: isInput ? "mic" : "speaker.wave.2"
                )
                Text(currentPort?.portName ?? "None")
                    .foregroundColor(.gray)
            }
            .font(.system(size: 16, weight: .medium))
            .foregroundColor(.white)
            .padding(12)
            .background(Color.gray.opacity(0.3))
            .cornerRadius(8)
            .frame(minWidth: 44, minHeight: 44)
        }
    }
} 