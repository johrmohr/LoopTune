import SwiftUI

struct CustomTabView: View {
    @Binding var selectedTab: Int
    
    var body: some View {
        HStack(spacing: 30) {
            TabButton(title: "Loop", icon: "waveform.circle.fill", isSelected: selectedTab == 0) {
                withAnimation {
                    selectedTab = 0
                }
            }
            
            TabButton(title: "Tune", icon: "pianokeys", isSelected: selectedTab == 1) {
                withAnimation {
                    selectedTab = 1
                }
            }
        }
        .frame(height: 50)
        .frame(maxWidth: .infinity)
        .background(Color(.systemGray6))
    }
}

struct TabButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                Text(title)
                    .font(.caption)
            }
            .foregroundColor(isSelected ? .blue : .gray)
        }
    }
} 