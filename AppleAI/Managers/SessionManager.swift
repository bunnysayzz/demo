import Foundation
import WebKit
import Combine

/// Comprehensive session management for AI assistants
/// Handles session persistence, state recovery, and data management
@available(macOS 11.0, *)
class SessionManager: ObservableObject {
    static let shared = SessionManager()
    
    // MARK: - Published Properties
    
    /// Currently active sessions by service ID
    @Published private(set) var activeSessions: [String: SessionData] = [:]
    
    /// Last used service for quick restoration
    @Published var lastUsedService: AIService?
    
    /// Session statistics
    @Published private(set) var sessionStats: SessionStatistics = SessionStatistics()
    
    // MARK: - Private Properties
    
    private let fileManager = FileManager.default
    private let userDefaults = UserDefaults.standard
    private var cancellables = Set<AnyCancellable>()
    private let sessionQueue = DispatchQueue(label: "com.appleai.session", qos: .utility)
    
    // Session storage paths
    private lazy var sessionsDirectory: URL = {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDirectory = appSupport.appendingPathComponent("AppleAI")
        let sessionsDir = appDirectory.appendingPathComponent("Sessions")
        
        try? fileManager.createDirectory(at: sessionsDir, withIntermediateDirectories: true)
        return sessionsDir
    }()
    
    private lazy var statisticsURL: URL = {
        sessionsDirectory.appendingPathComponent("statistics.json")
    }()
    
    // MARK: - Initialization
    
    private init() {
        setupSessionMonitoring()
        loadSavedSessions()
        loadStatistics()
        
        // Auto-save periodically
        Timer.publish(every: 300, on: .main, in: .common) // Every 5 minutes
            .autoconnect()
            .sink { [weak self] _ in
                self?.saveAllSessions()
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Session Management
    
    /// Create or update a session for the given service
    func createOrUpdateSession(for service: AIService) {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            
            let sessionId = service.id.uuidString
            let now = Date()
            
            if var existingSession = self.activeSessions[sessionId] {
                // Update existing session
                existingSession.lastAccessed = now
                existingSession.accessCount += 1
                self.activeSessions[sessionId] = existingSession
            } else {
                // Create new session
                let newSession = SessionData(
                    id: sessionId,
                    serviceName: service.name,
                    serviceURL: service.url,
                    createdAt: now,
                    lastAccessed: now,
                    accessCount: 1
                )
                self.activeSessions[sessionId] = newSession
            }
            
            // Update last used service
            DispatchQueue.main.async {
                self.lastUsedService = service
                self.updateStatistics(for: service)
            }
            
            // Save session data
            self.saveSession(sessionId: sessionId)
        }
    }
    
    /// Get session data for a service
    func getSession(for service: AIService) -> SessionData? {
        return activeSessions[service.id.uuidString]
    }
    
    /// Remove a session
    func removeSession(for service: AIService) {
        let sessionId = service.id.uuidString
        
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            
            self.activeSessions.removeValue(forKey: sessionId)
            
            // Remove session file
            let sessionURL = self.sessionsDirectory.appendingPathComponent("\(sessionId).json")
            try? self.fileManager.removeItem(at: sessionURL)
            
            DispatchQueue.main.async {
                self.objectWillChange.send()
            }
        }
    }
    
    /// Clear all sessions
    func clearAllSessions() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            
            self.activeSessions.removeAll()
            
            // Remove all session files
            if let sessionFiles = try? self.fileManager.contentsOfDirectory(at: self.sessionsDirectory, includingPropertiesForKeys: nil) {
                for file in sessionFiles where file.pathExtension == "json" && file.lastPathComponent != "statistics.json" {
                    try? self.fileManager.removeItem(at: file)
                }
            }
            
            DispatchQueue.main.async {
                self.objectWillChange.send()
            }
        }
    }
    
    /// Get recently used services
    func getRecentlyUsedServices(limit: Int = 5) -> [AIService] {
        let recentSessions = activeSessions.values
            .sorted { $0.lastAccessed > $1.lastAccessed }
            .prefix(limit)
        
        return recentSessions.compactMap { session in
            aiServices.first { $0.id.uuidString == session.id }
        }
    }
    
    /// Get session duration for a service
    func getSessionDuration(for service: AIService) -> TimeInterval? {
        guard let session = getSession(for: service) else { return nil }
        return Date().timeIntervalSince(session.createdAt)
    }
    
    // MARK: - Session Restoration
    
    /// Restore the last active session
    func restoreLastSession() -> AIService? {
        // Try to get the last used service from UserDefaults first
        if let lastServiceName = userDefaults.string(forKey: "lastUsedServiceName"),
           let service = aiServices.first(where: { $0.name == lastServiceName }) {
            return service
        }
        
        // Fallback to most recently accessed session
        return getRecentlyUsedServices(limit: 1).first
    }
    
    /// Save current session state
    func saveCurrentState(for service: AIService, webView: WKWebView? = nil) {
        sessionQueue.async { [weak self] in
            guard let self = self,
                  var session = self.activeSessions[service.id.uuidString] else { return }
            
            // Update session with current state
            session.lastAccessed = Date()
            
            // Save current URL if different from service URL
            if let webView = webView, let currentURL = webView.url, currentURL != service.url {
                session.currentURL = currentURL
            }
            
            // Save scroll position and other state if needed
            if let webView = webView {
                webView.evaluateJavaScript("window.pageYOffset") { result, _ in
                    if let scrollPosition = result as? Double {
                        session.scrollPosition = scrollPosition
                    }
                }
            }
            
            self.activeSessions[service.id.uuidString] = session
            self.saveSession(sessionId: service.id.uuidString)
        }
    }
    
    // MARK: - Statistics
    
    private func updateStatistics(for service: AIService) {
        sessionStats.totalSessions += 1
        sessionStats.lastUsedDate = Date()
        
        // Update service usage count
        let serviceName = service.name
        sessionStats.serviceUsageCount[serviceName] = (sessionStats.serviceUsageCount[serviceName] ?? 0) + 1
        
        // Update daily usage
        let today = Calendar.current.startOfDay(for: Date())
        sessionStats.dailyUsage[today] = (sessionStats.dailyUsage[today] ?? 0) + 1
        
        saveStatistics()
    }
    
    /// Get usage statistics for a specific service
    func getUsageStatistics(for service: AIService) -> Int {
        return sessionStats.serviceUsageCount[service.name] ?? 0
    }
    
    /// Get total usage time
    func getTotalUsageTime() -> TimeInterval {
        return activeSessions.values.reduce(0) { total, session in
            total + Date().timeIntervalSince(session.createdAt)
        }
    }
    
    // MARK: - Session Monitoring
    
    private func setupSessionMonitoring() {
        // Monitor app lifecycle events
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationWillTerminate),
            name: NSApplication.willTerminateNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationDidResignActive),
            name: NSApplication.didResignActiveNotification,
            object: nil
        )
        
        // Monitor theme changes to update session preferences
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(themeDidChange),
            name: Notification.Name("ThemeAppearanceChanged"),
            object: nil
        )
    }
    
    @objc private func applicationWillTerminate() {
        saveAllSessions()
        saveStatistics()
        
        // Save last used service
        if let lastService = lastUsedService {
            userDefaults.set(lastService.name, forKey: "lastUsedServiceName")
        }
    }
    
    @objc private func applicationDidResignActive() {
        saveAllSessions()
    }
    
    @objc private func themeDidChange() {
        // Update session preferences with current theme
        sessionStats.lastThemeChange = Date()
        saveStatistics()
    }
    
    // MARK: - Persistence
    
    private func saveSession(sessionId: String) {
        guard let session = activeSessions[sessionId] else { return }
        
        let sessionURL = sessionsDirectory.appendingPathComponent("\(sessionId).json")
        
        do {
            let data = try JSONEncoder().encode(session)
            try data.write(to: sessionURL)
        } catch {
            print("Error saving session \(sessionId): \(error)")
        }
    }
    
    private func saveAllSessions() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            
            for sessionId in self.activeSessions.keys {
                self.saveSession(sessionId: sessionId)
            }
        }
    }
    
    private func loadSavedSessions() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            
            do {
                let sessionFiles = try self.fileManager.contentsOfDirectory(at: self.sessionsDirectory, includingPropertiesForKeys: nil)
                
                for file in sessionFiles where file.pathExtension == "json" && file.lastPathComponent != "statistics.json" {
                    do {
                        let data = try Data(contentsOf: file)
                        let session = try JSONDecoder().decode(SessionData.self, from: data)
                        self.activeSessions[session.id] = session
                    } catch {
                        print("Error loading session from \(file): \(error)")
                        // Remove corrupted session file
                        try? self.fileManager.removeItem(at: file)
                    }
                }
                
                DispatchQueue.main.async {
                    self.objectWillChange.send()
                }
            } catch {
                print("Error loading sessions directory: \(error)")
            }
        }
    }
    
    private func saveStatistics() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            
            do {
                let data = try JSONEncoder().encode(self.sessionStats)
                try data.write(to: self.statisticsURL)
            } catch {
                print("Error saving statistics: \(error)")
            }
        }
    }
    
    private func loadStatistics() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            
            do {
                let data = try Data(contentsOf: self.statisticsURL)
                let stats = try JSONDecoder().decode(SessionStatistics.self, from: data)
                
                DispatchQueue.main.async {
                    self.sessionStats = stats
                }
            } catch {
                // Create default statistics if file doesn't exist or is corrupted
                DispatchQueue.main.async {
                    self.sessionStats = SessionStatistics()
                }
            }
        }
    }
    
    // MARK: - Data Export/Import
    
    /// Export session data for backup
    func exportSessionData() -> Data? {
        do {
            let exportData = SessionExportData(
                sessions: Array(activeSessions.values),
                statistics: sessionStats,
                exportDate: Date()
            )
            return try JSONEncoder().encode(exportData)
        } catch {
            print("Error exporting session data: \(error)")
            return nil
        }
    }
    
    /// Import session data from backup
    func importSessionData(_ data: Data) -> Bool {
        do {
            let importData = try JSONDecoder().decode(SessionExportData.self, from: data)
            
            // Import sessions
            for session in importData.sessions {
                activeSessions[session.id] = session
            }
            
            // Merge statistics
            sessionStats.merge(with: importData.statistics)
            
            // Save imported data
            saveAllSessions()
            saveStatistics()
            
            return true
        } catch {
            print("Error importing session data: \(error)")
            return false
        }
    }
}

// MARK: - Data Models

/// Session data for individual AI services
struct SessionData: Codable, Identifiable {
    let id: String
    let serviceName: String
    let serviceURL: URL
    let createdAt: Date
    var lastAccessed: Date
    var accessCount: Int
    var currentURL: URL?
    var scrollPosition: Double?
    var customSettings: [String: String] = [:]
    
    // Computed properties
    var duration: TimeInterval {
        Date().timeIntervalSince(createdAt)
    }
    
    var isActive: Bool {
        Date().timeIntervalSince(lastAccessed) < 3600 // Active if accessed within last hour
    }
}

/// Session statistics and analytics
struct SessionStatistics: Codable {
    var totalSessions: Int = 0
    var lastUsedDate: Date?
    var lastThemeChange: Date?
    var serviceUsageCount: [String: Int] = [:]
    var dailyUsage: [Date: Int] = [:]
    
    mutating func merge(with other: SessionStatistics) {
        totalSessions = max(totalSessions, other.totalSessions)
        
        if let otherDate = other.lastUsedDate {
            if let currentDate = lastUsedDate {
                lastUsedDate = max(currentDate, otherDate)
            } else {
                lastUsedDate = otherDate
            }
        }
        
        // Merge service usage counts
        for (service, count) in other.serviceUsageCount {
            serviceUsageCount[service] = (serviceUsageCount[service] ?? 0) + count
        }
        
        // Merge daily usage
        for (date, count) in other.dailyUsage {
            dailyUsage[date] = (dailyUsage[date] ?? 0) + count
        }
    }
}

/// Export/import data structure
struct SessionExportData: Codable {
    let sessions: [SessionData]
    let statistics: SessionStatistics
    let exportDate: Date
}

// MARK: - Extensions

extension SessionManager {
    /// Get session summary for display
    func getSessionSummary() -> String {
        let totalSessions = activeSessions.count
        let totalUsage = getTotalUsageTime()
        let hours = Int(totalUsage) / 3600
        let minutes = (Int(totalUsage) % 3600) / 60
        
        return "Sessions: \(totalSessions) • Usage: \(hours)h \(minutes)m"
    }
    
    /// Get most used service
    func getMostUsedService() -> AIService? {
        guard let mostUsedServiceName = sessionStats.serviceUsageCount.max(by: { $0.value < $1.value })?.key else {
            return nil
        }
        
        return aiServices.first { $0.name == mostUsedServiceName }
    }
}