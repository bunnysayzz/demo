import SwiftUI
import AppKit

struct EnhancedPinButton: View {
    @Binding var isPinned: Bool
    
    var body: some View {
        Button(action: {
            isPinned.toggle()
        }) {
            Image(systemName: isPinned ? "pin.fill" : "pin")
                .symbolRenderingMode(.hierarchical)
                .foregroundColor(isPinned ? .accentColor : .secondary)
                .frame(width: 16, height: 16)
                .help(isPinned ? "Unpin Window" : "Pin Window")
        }
        .buttonStyle(BorderlessButtonStyle())
    }
}

// Preview provider for SwiftUI canvas
struct EnhancedPinButton_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            EnhancedPinButton(isPinned: .constant(false))
                .previewDisplayName("Unpinned")
            
            EnhancedPinButton(isPinned: .constant(true))
                .previewDisplayName("Pinned")
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
} 