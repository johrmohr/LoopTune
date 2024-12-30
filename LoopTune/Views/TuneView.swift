import SwiftUI
import UniformTypeIdentifiers

struct TuneView: View {
    @StateObject private var soundboardEngine = SoundboardEngine()
    @State private var isShowingFilePicker = false
    @State private var selectedButtonIndex: Int?
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    
    var columns: [GridItem] {
        // Use 2x4 for portrait, 4x2 for landscape
        let isPortrait = UIScreen.main.bounds.height > UIScreen.main.bounds.width
        return Array(repeating: GridItem(.flexible(), spacing: 16), count: isPortrait ? 2 : 4)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            GeometryReader { geometry in
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(0..<8) { index in
                        if index < soundboardEngine.buttons.count {
                            createSoundPadButton(for: index, button: soundboardEngine.buttons[index])
                                .frame(height: buttonHeight(for: geometry))
                        }
                    }
                }
                .padding(16)
            }
            
            editButton
        }
        .fileImporter(
            isPresented: $isShowingFilePicker,
            allowedContentTypes: [.audio, .mp3, .wav, .aac, .m4a],
            allowsMultipleSelection: false,
            onCompletion: handleFileImport
        )
        .navigationTitle("Tune")
    }
    
    private func buttonHeight(for geometry: GeometryProxy) -> CGFloat {
        let isPortrait = geometry.size.height > geometry.size.width
        let padding: CGFloat = 48 // Total vertical padding (16 * 3)
        let spacing: CGFloat = isPortrait ? 48 : 16 // Total spacing (16 * 3 for portrait, 16 for landscape)
        let editButtonHeight: CGFloat = 50
        
        if isPortrait {
            // For 2x4 layout
            return (geometry.size.height - padding - spacing - editButtonHeight) / 4
        } else {
            // For 4x2 layout
            return (geometry.size.height - padding - spacing - editButtonHeight) / 2
        }
    }
    
    private var editButton: some View {
        Button(action: {
            withAnimation {
                soundboardEngine.isEditMode.toggle()
            }
        }) {
            Text(soundboardEngine.isEditMode ? "Done" : "Edit")
                .font(.headline)
                .foregroundColor(soundboardEngine.isEditMode ? .red : .blue)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(Color(.systemGray6))
        }
    }
    
    private func createSoundPadButton(for index: Int, button: SoundButton) -> some View {
        SoundPadButton(
            title: button.title,
            hasSound: button.soundURL != nil,
            isEditMode: soundboardEngine.isEditMode,
            isRecording: soundboardEngine.isRecording && soundboardEngine.currentRecordingIndex == index,
            action: { handleButtonAction(index: index, button: button) },
            recordAction: { handleRecordAction(index: index) }
        )
    }
    
    private func handleButtonAction(index: Int, button: SoundButton) {
        if soundboardEngine.isEditMode {
            if button.soundURL != nil {
                soundboardEngine.removeSound(at: index)
            }
        } else if button.soundURL != nil {
            soundboardEngine.playSound(at: index)
        } else {
            selectedButtonIndex = index
            isShowingFilePicker = true
        }
    }
    
    private func handleRecordAction(index: Int) {
        if soundboardEngine.isRecording {
            soundboardEngine.stopRecording()
        } else {
            soundboardEngine.startRecording(for: index)
        }
    }
    
    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first,
                  let selectedIndex = selectedButtonIndex else { return }
            
            DispatchQueue.global(qos: .userInitiated).async {
                soundboardEngine.assignSound(at: selectedIndex, url: url)
            }
            
        case .failure(let error):
            print("File import failed: \(error.localizedDescription)")
        }
    }
}

struct SoundPadButton: View {
    let title: String
    let hasSound: Bool
    let isEditMode: Bool
    let isRecording: Bool
    let action: () -> Void
    let recordAction: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                // Icon
                Group {
                    if hasSound {
                        if isEditMode {
                            Menu {
                                Button(role: .destructive, action: action) {
                                    Label("Remove", systemImage: "trash")
                                }
                                Button(action: recordAction) {
                                    Label("Record New", systemImage: "mic.fill")
                                }
                            } label: {
                                Image(systemName: "ellipsis.circle.fill")
                                    .font(.system(size: 32))
                            }
                        } else {
                            Image(systemName: "play.fill")
                                .font(.system(size: 32))
                        }
                    } else {
                        if isRecording {
                            Image(systemName: "stop.fill")
                                .font(.system(size: 32))
                                .foregroundColor(.red)
                        } else {
                            Menu {
                                Button(action: action) {
                                    Label("Choose File", systemImage: "doc.fill")
                                }
                                Button(action: recordAction) {
                                    Label("Record", systemImage: "mic.fill")
                                }
                            } label: {
                                Image(systemName: "plus")
                                    .font(.system(size: 32))
                            }
                        }
                    }
                }
                .foregroundColor(hasSound ? .blue : .gray)
                
                // Title
                Text(title)
                    .font(.subheadline)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemGray6))
                    .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// Add these extensions to support more audio formats
extension UTType {
    static var mp3: UTType { UTType(filenameExtension: "mp3")! }
    static var wav: UTType { UTType(filenameExtension: "wav")! }
    static var aac: UTType { UTType(filenameExtension: "aac")! }
    static var m4a: UTType { UTType(filenameExtension: "m4a")! }
} 