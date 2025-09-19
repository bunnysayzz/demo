import Foundation
import AppKit
import SwiftUI
import WebKit

class GoogleAuthManager: ObservableObject {
    static let shared = GoogleAuthManager()
    
    // User profile data
    @Published var isUserLoggedIn: Bool = false
    @Published var userName: String = ""
    @Published var userEmail: String = ""
    @Published var userPhotoURL: URL?
    
    // Constants - Replace with real client ID in production
    private let clientID = "298547187780-g7mvn2n3c6j6n5iv2ljpsvt5r7hkicm0.apps.googleusercontent.com"
    private let redirectURI = "com.appleai.app:/oauth2callback"
    private let scopes = ["profile", "email"]
    
    // URL session for API calls
    private let session = URLSession.shared
    
    // Local storage keys
    private let tokenKey = "google_access_token"
    private let refreshTokenKey = "google_refresh_token"
    private let userDataKey = "google_user_data"
    private let isLoggedInKey = "isGoogleLoggedIn"
    private let userNameKey = "googleUserName"
    private let userEmailKey = "googleUserEmail"
    private let userPhotoKey = "googleUserPhoto"
    
    private init() {
        // Load cached user data
        loadUserDataFromCache()
    }
    
    // Load user data from UserDefaults
    private func loadUserDataFromCache() {
        self.isUserLoggedIn = UserDefaults.standard.bool(forKey: isLoggedInKey)
        self.userName = UserDefaults.standard.string(forKey: userNameKey) ?? ""
        self.userEmail = UserDefaults.standard.string(forKey: userEmailKey) ?? ""
        
        if let photoURLString = UserDefaults.standard.string(forKey: userPhotoKey),
           let photoURL = URL(string: photoURLString) {
            self.userPhotoURL = photoURL
        }
    }
    
    // Open browser for Google login with proper account selection
    func signIn() {
        // FOR DEMONSTRATION: Since we don't have a registered OAuth client,
        // we'll open the account selection page and simulate the login
        if let signInURL = URL(string: "https://accounts.google.com/signin/v2/identifier?service=mail") {
            NSWorkspace.shared.open(signInURL)
            
            // Simulate successful sign-in after delay
            // In a real app, this would happen through URL callback
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                self.simulateSuccessfulSignIn()
            }
        }
    }
    
    // Simulate successful sign-in (for demo purposes only)
    private func simulateSuccessfulSignIn() {
        // Generate random user profile
        let demoNames = ["John Doe", "Alice Smith", "Robert Johnson", "Maria Garcia", "Wei Chen"]
        let demoName = demoNames[Int.random(in: 0..<demoNames.count)]
        let demoEmail = demoName.lowercased().replacingOccurrences(of: " ", with: ".") + "@gmail.com"
        let demoPhotoURL = "https://xsgames.co/randomusers/avatar.php?g=pixel&key=\(Int.random(in: 1...5))"
        
        // Save to UserDefaults
        UserDefaults.standard.set(true, forKey: isLoggedInKey)
        UserDefaults.standard.set(demoName, forKey: userNameKey)
        UserDefaults.standard.set(demoEmail, forKey: userEmailKey)
        UserDefaults.standard.set(demoPhotoURL, forKey: userPhotoKey)
        
        // Update published properties
        DispatchQueue.main.async {
            self.isUserLoggedIn = true
            self.userName = demoName
            self.userEmail = demoEmail
            self.userPhotoURL = URL(string: demoPhotoURL)
        }
    }
    
    // Sign out user
    func signOut() {
        // Clear user data
        UserDefaults.standard.set(false, forKey: isLoggedInKey)
        UserDefaults.standard.removeObject(forKey: userNameKey)
        UserDefaults.standard.removeObject(forKey: userEmailKey)
        UserDefaults.standard.removeObject(forKey: userPhotoKey)
        UserDefaults.standard.removeObject(forKey: tokenKey)
        UserDefaults.standard.removeObject(forKey: refreshTokenKey)
        
        // Update UI
        DispatchQueue.main.async {
            self.isUserLoggedIn = false
            self.userName = ""
            self.userEmail = ""
            self.userPhotoURL = nil
        }
    }
    
    // For real OAuth implementation - these would be implemented
    
    /* 
    // Handle URL callback from browser
    func handleURL(_ url: URL) -> Bool {
        guard url.scheme == "com.appleai.app" else { return false }
        
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let code = components.queryItems?.first(where: { $0.name == "code" })?.value else {
            return false
        }
        
        exchangeCodeForTokens(code)
        return true
    }
    
    // Exchange authorization code for access tokens
    private func exchangeCodeForTokens(_ code: String) {
        var request = URLRequest(url: URL(string: "https://oauth2.googleapis.com/token")!)
        request.httpMethod = "POST"
        request.addValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let parameters = [
            "code": code,
            "client_id": clientID,
            "redirect_uri": redirectURI,
            "grant_type": "authorization_code"
        ]
        
        let bodyString = parameters.map { "\($0.key)=\($0.value)" }.joined(separator: "&")
        request.httpBody = bodyString.data(using: .utf8)
        
        let task = session.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self,
                  let data = data,
                  error == nil,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let accessToken = json["access_token"] as? String else {
                return
            }
            
            // Save tokens
            UserDefaults.standard.set(accessToken, forKey: self.tokenKey)
            if let refreshToken = json["refresh_token"] as? String {
                UserDefaults.standard.set(refreshToken, forKey: self.refreshTokenKey)
            }
            
            // Fetch user info with the token
            self.fetchUserInfo(accessToken)
        }
        
        task.resume()
    }
    
    // Fetch user profile information
    private func fetchUserInfo(_ accessToken: String) {
        var request = URLRequest(url: URL(string: "https://www.googleapis.com/oauth2/v2/userinfo")!)
        request.addValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        
        let task = session.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self,
                  let data = data,
                  error == nil,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                return
            }
            
            // Save user profile data
            let name = json["name"] as? String ?? "User"
            let email = json["email"] as? String ?? ""
            let photoURLString = json["picture"] as? String
            
            UserDefaults.standard.set(true, forKey: self.isLoggedInKey)
            UserDefaults.standard.set(name, forKey: self.userNameKey)
            UserDefaults.standard.set(email, forKey: self.userEmailKey)
            if let photoURLString = photoURLString {
                UserDefaults.standard.set(photoURLString, forKey: self.userPhotoKey)
            }
            
            // Update UI
            DispatchQueue.main.async {
                self.isUserLoggedIn = true
                self.userName = name
                self.userEmail = email
                if let photoURLString = photoURLString,
                   let photoURL = URL(string: photoURLString) {
                    self.userPhotoURL = photoURL
                }
            }
        }
        
        task.resume()
    }
    */
}
        
        let bodyString = parameters.map { "\($0.key)=\($0.value)" }.joined(separator: "&")
        request.httpBody = bodyString.data(using: .utf8)
        
        let task = session.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self,
                  let data = data,
                  error == nil,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let accessToken = json["access_token"] as? String else {
                // Refresh failed, sign out
                DispatchQueue.main.async {
                    self.signOut()
                }
                return
            }
            
            // Save new access token
            UserDefaults.standard.set(accessToken, forKey: self.tokenKey)
            
            // Fetch user info with new token
            self.fetchUserInfo(accessToken)
        }
        
        task.resume()
    }
    
    // Load user data from cache
    private func loadUserDataFromCache() {
        if let userData = UserDefaults.standard.data(forKey: userDataKey),
           let json = try? JSONSerialization.jsonObject(with: userData) as? [String: Any] {
            DispatchQueue.main.async {
                self.isUserLoggedIn = true
                self.userName = json["name"] as? String ?? "User"
                self.userEmail = json["email"] as? String ?? ""
                if let pictureURLString = json["picture"] as? String,
                   let pictureURL = URL(string: pictureURLString) {
                    self.userPhotoURL = pictureURL
                }
            }
        }
    }
}

// Extension to load images from URL
extension NSImage {
    static func loadFrom(url: URL, completion: @escaping (NSImage?) -> Void) {
        DispatchQueue.global().async {
            if let data = try? Data(contentsOf: url) {
                let image = NSImage(data: data)
                DispatchQueue.main.async {
                    completion(image)
                }
            } else {
                DispatchQueue.main.async {
                    completion(nil)
                }
            }
        }
    }
}

// SwiftUI Image view for profile pictures
struct ProfileImageView: View {
    let url: URL?
    @State private var image: NSImage?
    let size: CGFloat
    
    init(url: URL?, size: CGFloat = 40) {
        self.url = url
        self.size = size
    }
    
    var body: some View {
        Group {
            if let image = image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size, height: size)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                    )
            } else {
                Image(systemName: "person.circle.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .foregroundColor(.gray)
                    .frame(width: size, height: size)
            }
        }
        .onAppear {
            loadImage()
        }
        .onChange(of: url) { _ in
            loadImage()
        }
    }
    
    private func loadImage() {
        guard let url = url else { return }
        
        NSImage.loadFrom(url: url) { loadedImage in
            self.image = loadedImage
        }
    }
}
