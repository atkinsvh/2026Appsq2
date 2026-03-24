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
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private static let schemaMetadataFile = "schema_metadata.json"

    struct SchemaMetadata: Codable {
        var version: Int
        var updatedAt: Date
    }

    enum LocalSchemaVersion: Int, CaseIterable {
        case v1 = 1
        case v2 = 2

        static var latest: LocalSchemaVersion { .v2 }
    }

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
            let data = try encoder.encode(object)

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
            return try decoder.decode(type, from: data)
        } catch {
            // If file doesn't exist, that's okay - return nil
            if !fileManager.fileExists(atPath: fileURL.path) {
                return nil
            }
            print("⚠️ DataStore: Failed to load \(fileName): \(error)")
            return loadFromBackup(type, fileName: fileName)
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

            // Clean up old backups for this file (keep last 5 most recent)
            let backups = try? fileManager.contentsOfDirectory(at: backupURL, includingPropertiesForKeys: nil)
            if let backups = backups {
                for backup in Self.backupsToPrune(backups, for: fileName) {
                    try? fileManager.removeItem(at: backup)
                }
            }
        } catch {
            // Backup failed - not critical, just log it
            print("⚠️ Backup failed for \(fileName)")
        }
    }

    private func loadFromBackup<T: Codable>(_ type: T.Type, fileName: String) -> T? {
        guard let backups = try? fileManager.contentsOfDirectory(at: backupURL, includingPropertiesForKeys: nil) else {
            return nil
        }

        let candidates = Self.backupCandidates(backups, for: fileName)
        for backupURL in candidates {
            do {
                let data = try Data(contentsOf: backupURL)
                let restored = try decoder.decode(type, from: data)
                lastError = "Recovered \(fileName) from backup"
                return restored
            } catch {
                continue
            }
        }

        return nil
    }

    static func backupCandidates(_ backups: [URL], for fileName: String) -> [URL] {
        backups
            .filter { $0.lastPathComponent.hasSuffix("-\(fileName)") }
            .sorted { $0.lastPathComponent > $1.lastPathComponent }
    }

    static func backupsToPrune(_ backups: [URL], for fileName: String, keepLast keepCount: Int = 5) -> [URL] {
        let matchingBackups = backupCandidates(backups, for: fileName)
        guard matchingBackups.count > keepCount else { return [] }
        return Array(matchingBackups.dropFirst(keepCount))
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

    // MARK: - Schema Versioning + Migration

    func migrateToLatestSchema() -> [String] {
        var notes: [String] = []
        let current = currentSchemaVersion()
        let latest = LocalSchemaVersion.latest.rawValue

        guard current < latest else {
            return ["Schema already at v\(latest)"]
        }

        for version in (current + 1)...latest {
            switch version {
            case LocalSchemaVersion.v2.rawValue:
                notes.append(contentsOf: migrateV1toV2())
            default:
                notes.append("No migration runner for v\(version)")
            }
        }

        setSchemaVersion(latest)
        notes.append("Schema migration complete: v\(current) -> v\(latest)")
        return notes
    }

    func currentSchemaVersion() -> Int {
        load(SchemaMetadata.self, from: Self.schemaMetadataFile)?.version ?? LocalSchemaVersion.v1.rawValue
    }

    private func setSchemaVersion(_ version: Int) {
        let metadata = SchemaMetadata(version: version, updatedAt: Date())
        _ = save(metadata, to: Self.schemaMetadataFile)
    }

    private func migrateV1toV2() -> [String] {
        var notes: [String] = ["Running migration v1 -> v2"]

        if var guests = load([Guest].self, from: "guests.json") {
            var changedCount = 0
            guests = guests.map { guest in
                var updated = guest
                let normalizedCode = guest.invitationCode.map(InvitationCode.normalize)
                if updated.invitationCode != normalizedCode {
                    updated.invitationCode = normalizedCode
                    changedCount += 1
                }
                if updated.partySize < 1 {
                    updated.partySize = 1
                    changedCount += 1
                }
                return updated
            }
            _ = save(guests, to: "guests.json")
            notes.append("Guests normalized: \(changedCount) updates")
        } else {
            notes.append("Guests file not found; skipped")
        }

        if var invitations = load([InvitationCode].self, from: "invitation_codes.json") {
            var changedCount = 0
            invitations = invitations.map { invitation in
                let normalized = InvitationCode.normalize(invitation.code)
                let normalizedPartySize = max(invitation.partySize, 1)
                if normalized != invitation.code || normalizedPartySize != invitation.partySize {
                    changedCount += 1
                }
                return InvitationCode(
                    id: invitation.id,
                    code: normalized,
                    weddingId: invitation.weddingId,
                    coupleNames: invitation.coupleNames,
                    weddingDate: invitation.weddingDate,
                    weddingLocation: invitation.weddingLocation,
                    createdAt: invitation.createdAt,
                    guestId: invitation.guestId,
                    guestName: invitation.guestName,
                    rsvpStatus: invitation.rsvpStatus,
                    mealChoice: invitation.mealChoice,
                    dietaryNotes: invitation.dietaryNotes,
                    partySize: normalizedPartySize,
                    phoneNumber: invitation.phoneNumber
                )
            }
            _ = save(invitations, to: "invitation_codes.json")
            notes.append("Invitation codes normalized: \(changedCount) updates")
        } else {
            notes.append("Invitation codes file not found; skipped")
        }

        if var rsvps = load([GuestRSVP].self, from: "all_guest_rsvps.json") {
            var changedCount = 0
            rsvps = rsvps.map { rsvp in
                let normalizedCode = InvitationCode.normalize(rsvp.invitationCode)
                let normalizedPartySize = max(rsvp.partySize, 1)
                if normalizedCode != rsvp.invitationCode || normalizedPartySize != rsvp.partySize {
                    changedCount += 1
                }
                return GuestRSVP(
                    invitationCode: normalizedCode,
                    guestName: rsvp.guestName,
                    rsvpStatus: rsvp.rsvpStatus,
                    mealChoice: rsvp.mealChoice,
                    dietaryNotes: rsvp.dietaryNotes,
                    partySize: normalizedPartySize,
                    submittedAt: rsvp.submittedAt
                )
            }
            _ = save(rsvps, to: "all_guest_rsvps.json")
            notes.append("RSVPs normalized: \(changedCount) updates")
        } else {
            notes.append("RSVP file not found; skipped")
        }

        return notes
    }
}
