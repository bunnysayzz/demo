import SwiftUI

struct MultiTabView: View {
    @State private var selectedService: AIService
    @StateObject private var preferences = PreferencesManager.shared
    let services: [AIService]
    
    // Computed property to get visible services based on preferences
    private var visibleServices: [AIService] {
        return services.filter { service in
            preferences.isModelVisible(service.name)
        }
    }
    
    init(services: [AIService] = aiServices) {
        self.services = services
        
        // Find first visible service as default
        let firstVisible = services.first { service in
            PreferencesManager.shared.isModelVisible(service.name)
        } ?? services.first!
        
        _selectedService = State(initialValue: firstVisible)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Tab bar
            HStack(spacing: 0) {
                ForEach(visibleServices) { service in
                    TabButton(
                        service: service,
                        isSelected: selectedService.id == service.id,
                        action: { selectedService = service }
                    )
                }
                Spacer()
            }
            .background(Color(NSColor.windowBackgroundColor))
            
            // Content area
            WebViewWindow(service: selectedService)
                .transition(.opacity)
                .id(selectedService.id) // Force view recreation when service changes
        }
        // Add observer for model visibility changes
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("ModelVisibilityChanged"))) { _ in
            // If the currently selected service is now hidden, switch to the first visible one
            if !preferences.isModelVisible(selectedService.name), let firstVisible = visibleServices.first {
                selectedService = firstVisible
            }
        }
    }
}

struct TabButton: View {
    let service: AIService
    let isSelected: Bool
    let action: () -> Void
    @StateObject private var preferences = PreferencesManager.shared
    
    // Computed property to get visible services count
    private var visibleServicesCount: Int {
        return aiServices.filter { preferences.isModelVisible($0.name) }.count
    }
    
    // Dynamic sizing based on number of visible services
    private var iconSize: CGFloat {
        if visibleServicesCount <= 4 {
            return 20 // Larger for fewer tabs
        } else if visibleServicesCount <= 6 {
            return 18
        } else {
            return 16 // Smaller for many tabs
        }
    }
    
    private var fontSize: CGFloat {
        if visibleServicesCount <= 4 {
            return 14
        } else if visibleServicesCount <= 6 {
            return 13
        } else {
            return 12
        }
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(service.icon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: iconSize, height: iconSize)
                Text(service.name)
                    .font(.system(size: fontSize, weight: isSelected ? .semibold : .regular))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                isSelected ? 
                    service.color.opacity(0.1) : 
                    Color.clear
            )
            .foregroundColor(isSelected ? service.color : .primary)
            .cornerRadius(8)
            .overlay(
                isSelected ?
                    Rectangle()
                        .frame(height: 2)
                        .foregroundColor(service.color)
                        .offset(y: 13) :
                    nil
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// Preview for SwiftUI Canvas
struct MultiTabView_Previews: PreviewProvider {
    static var previews: some View {
        MultiTabView()
            .frame(width: 800, height: 600)
    }
} 