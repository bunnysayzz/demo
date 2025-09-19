import SwiftUI
import WebKit

struct MainChatView: View {
    @State private var selectedService: AIService
    @State private var isLoading = true
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
    
    // Initialize with a specific service
    init(initialService: AIService, services: [AIService] = aiServices) {
        self.services = services
        _selectedService = State(initialValue: initialService)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Top bar with model selector
            HStack {
                Text("Apple AI Pro")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                // Model selector dropdown
                Picker("", selection: $selectedService) {
                    ForEach(visibleServices) { service in
                        HStack {
                            Image(service.icon)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 18, height: 18)
                                .foregroundColor(service.color)
                            Text(service.name)
                                .font(.system(size: 12))
                        }
                        .tag(service)
                    }
                }
                .pickerStyle(MenuPickerStyle())
                .frame(width: 160)
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))
            
            // Model indicator bar
            HStack {
                Image(selectedService.icon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 18, height: 18)
                    .foregroundColor(.white)
                Text(selectedService.name)
                    .foregroundColor(.white)
                    .fontWeight(.medium)
                
                Spacer()
                
                // Add file upload button
                Button(action: {
                    WebViewCache.shared.triggerFileUpload(for: selectedService)
                }) {
                    Image(systemName: "paperclip")
                        .foregroundColor(.white)
                        .font(.system(size: 14, weight: .medium))
                }
                .buttonStyle(BorderlessButtonStyle())
                .padding(.trailing, 8)
                .help("Attach files")
                
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.7)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(selectedService.color)
            
            // Web view for the selected service
            PersistentWebView(service: selectedService, isLoading: $isLoading)
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

// Preview for SwiftUI Canvas
struct MainChatView_Previews: PreviewProvider {
    static var previews: some View {
        MainChatView()
            .frame(width: 800, height: 600)
    }
} 