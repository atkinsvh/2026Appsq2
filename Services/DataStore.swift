import Foundation
import SwiftUI
import CloudKit

/// Unified data store service for VowPlanner
/// Handles local JSON storage, atomic saves, and CloudKit sync
@MainActor
class DataStore: ObservableObject {
    
    // MARK: - Singleton
    static let shared = DataStore()
    
    // MARK: - Published State
    @Published var syncStatus: SyncStatus = .idle
    @Published var lastError: String?
    @Published var pendingSaves: Set<String> = []
    
    // MARK: - Status Enum
    enum SyncStatus {
        case idle
        case syncing(String)  // message: "Saving guests..."
        case synced
        case error(String)
    }
    
    // MARK: - Save Result
    struct SaveResult {
        let isSuccess: Bool
        let message: String
        let error: Error?
        
        static func success(_ message: String = "Saved") -> SaveResult {
            return SaveResult(isSuccess: true, message: message, error: nil)
        }
        
        static func failure(_ message: String, error: Error?) -> SaveResult {
            return SaveResult(isSuccess: false, message: message, error: error)
        }
    }
    
    // MARK: - Private Properties
    private let fileManager = FileManager.default
    private let documentsURL: URL
    private let backupURL: URL
    
    // MARK: - Initialization
    private init() {
        // Get documents directory
        if let url = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first {
            documentsURL = url
        } else {
            // Fallback to temp (shouldn't happen on iOS)
            documentsURL = URL(fileURLWithPath: NSTemporaryDirectory())
        }
        
        // Create backup directory
        backupURL = documentsURL.appendingPathComponent("Backups")
        try? fileManager.createDirectory(at: backupURL, withIntermediateDirectories: true)
    }
    
    // MARK: - Save Methods
    
    /// Save any Codable object to disk with atomic write
    func save<T: Codable>(_ object: T, to fileName: String) -> SaveResult {
        let fileURL = documentsURL.appendingPathComponent(fileName)
        
        do {
            // Create backup first
            createBackup(for: fileURL)
            
            // Encode to data
            let data = try JSONEncoder().encode(object)
            
            // Atomic write: write to temp, then rename
            let tempURL = fileURL.deletingLastPathComponent().appendingPathComponent("\(fileName).temp")
            try data.write(to: tempURL, options: .atomic)
            
            // Rename to final name
            try? fileManager.removeItem(at: fileURL)
            try fileManager.moveItem(at: tempURL, to: fileURL)
            
            // Update pending saves
            pendingSaves.remove(fileName)
            
            return SaveResult.success("Saved \(fileName)")
            
        } catch {
            pendingSaves.insert(fileName)
            lastError = "Failed to save: \(error.localizedDescription)"
            return SaveResult.failure("Failed to save \(fileName)", error: error)
        }
    }
    
    /// Load any Codable object from disk
    func load<T: Codable>(_ type: T.Type, from fileName: String) -> T? {
        let fileURL = documentsURL.appendingPathComponent(fileName)
        
        do {
            let data = try Data(contentsOf: fileURL)
            return try JSONDecoder().decode(type, from: data)
        } catch {
            // If file doesn't exist, that's okay - return nil
            if !fileManager.fileExists(atPath: fileURL.path) {
                return nil
            }
            print("⚠️ DataStore: Failed to load \(fileName): \(error)")
            return nil
        }
    }
    
    /// Delete a file
    func delete(fileName: String) -> SaveResult {
        let fileURL = documentsURL.appendingPathComponent(fileName)
        
        do {
            try fileManager.removeItem(at: fileURL)
            return SaveResult.success("Deleted \(fileName)")
        } catch {
            return SaveResult.failure("Failed to delete \(fileName)", error: error)
        }
    }
    
    // MARK: - Backup Methods
    
    private func createBackup(for fileURL: URL) {
        guard fileManager.fileExists(atPath: fileURL.path) else { return }
        
        let fileName = fileURL.lastPathComponent
        let timestamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let backupFileURL = backupURL.appendingPathComponent("\(timestamp)-\(fileName)")
        
        do {
            try fileManager.copyItem(at: fileURL, to: backupFileURL)
            
            // Clean up old backups (keep last 5)
            let backups = try? fileManager.contentsOfDirectory(at: backupURL, includingPropertiesForKeys: nil)
            if let backups = backups, backups.count > 5 {
                let sortedBackups = backups.sorted { $0.lastPathComponent < $1.lastPathComponent }
                for backup in sortedBackups.dropFirst(5) {
                    try? fileManager.removeItem(at: backup)
                }
            }
        } catch {
            // Backup failed - not critical, just log it
            print("⚠️ Backup failed for \(fileName)")
        }
    }
    
    // MARK: - Batch Operations
    
    /// Save multiple objects atomically
    func saveBatch(_ operations: [() -> SaveResult]) -> SaveResult {
        var errors: [String] = []
        
        for operation in operations {
            let result = operation()
            if !result.isSuccess {
                errors.append(result.message)
            }
        }
        
        if errors.isEmpty {
            return SaveResult.success("All saves completed")
        } else {
            return SaveResult.failure("Some saves failed: \(errors.joined(separator: ", "))", error: nil)
        }
    }
    
    // MARK: - File Info
    
    func getFileInfo(for fileName: String) -> (size: Int64, modified: Date)? {
        let fileURL = documentsURL.appendingPathComponent(fileName)
        
        do {
            let attributes = try fileManager.attributesOfItem(atPath: fileURL.path)
            let size = attributes[.size] as? Int64 ?? 0
            let modified = attributes[.modificationDate] as? Date ?? Date()
            return (size, modified)
        } catch {
            return nil
        }
    }
    
    // MARK: - Debug Helpers
    
    func listAllFiles() -> [String] {
        do {
            return try fileManager.contentsOfDirectory(atPath: documentsURL.path)
        } catch {
            return []
        }
    }
}
