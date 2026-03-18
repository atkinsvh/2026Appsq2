//
//  AppState.swift
//  VowPlanner
//

import Foundation
import SwiftUI
import CloudKit

@MainActor
class AppState: ObservableObject {
    private static let onboardingCompletedKey = "AppState.onboardingCompleted"
    private static let weddingIdKey = "AppState.weddingId"
    private static let isCoPlannerKey = "AppState.isCoPlanner"
    private static let guestWeddingIdKey = "AppState.guestWeddingId"
    private static let weddingDetailsFile = "wedding_details.json"
    private static let guestsFile = "guests.json"
    private static let budgetFile = "budget_categories.json"
    private static let vendorsFile = "vendors.json"
    private static let allGuestRSVPsFile = "all_guest_rsvps.json"
    
    // Unified data store
    let dataStore = DataStore.shared
    
    // CloudKit sync service
    let cloudKitSync = CloudKitSyncService()
    
    // Minimal shared state - only UI coordination
    @Published var onboardingCompleted: Bool = false {
        didSet {
            UserDefaults.standard.set(onboardingCompleted, forKey: Self.onboardingCompletedKey)
        }
    }
    @Published var partnerInvited: Bool = false
    @Published var tooltipsDismissed: Set<String> = []
    @Published var weddingDetails: WeddingDetails = WeddingDetails(coupleNames: "", date: Date(), location: "") {
        didSet {
            _ = dataStore.save(weddingDetails, to: Self.weddingDetailsFile)
        }
    }
    
    // Guest Mode
    @Published var isGuestMode: Bool = false
    @Published var currentInvitationCode: String?
    @Published var guestRSVP: GuestRSVP?
    @Published var guestWeddingId: UUID? {
        didSet {
            UserDefaults.standard.set(guestWeddingId?.uuidString, forKey: Self.guestWeddingIdKey)
        }
    }
    
    // Co-planner mode
    @Published var isCoPlanner: Bool = false {
        didSet {
            UserDefaults.standard.set(isCoPlanner, forKey: Self.isCoPlannerKey)
        }
    }
    @Published var weddingId: UUID? {
        didSet {
            UserDefaults.standard.set(weddingId?.uuidString, forKey: Self.weddingIdKey)
        }
    }
    
    init() {
        onboardingCompleted = UserDefaults.standard.bool(forKey: Self.onboardingCompletedKey)
        isCoPlanner = UserDefaults.standard.bool(forKey: Self.isCoPlannerKey)
        if let weddingIdString = UserDefaults.standard.string(forKey: Self.weddingIdKey) {
            weddingId = UUID(uuidString: weddingIdString)
        }
        if let guestWeddingIdString = UserDefaults.standard.string(forKey: Self.guestWeddingIdKey) {
            guestWeddingId = UUID(uuidString: guestWeddingIdString)
        }
        
        loadGuestMode()
        
        // Auto-sync when app launches (for host or co-planner)
        if !isGuestMode, weddingId != nil {
            Task {
                await syncFromCloudKit()
            }
        }
    }
    
    private func syncFromCloudKit() async {
        guard let weddingId = weddingId else { return }
        
        do {
            let (cloudWedding, cloudGuests, cloudBudget, cloudVendors) = try await cloudKitSync.syncAllData(weddingId: weddingId)
            
            // Sync wedding details
            if let cloudWedding = cloudWedding {
                self.weddingDetails = cloudWedding
            }
            
            // Merge guests (CloudKit wins for last write)
            var localGuests = dataStore.load([Guest].self, from: Self.guestsFile) ?? []
            for cloudGuest in cloudGuests {
                if let index = localGuests.firstIndex(where: { $0.id == cloudGuest.id }) {
                    localGuests[index] = cloudGuest
                } else {
                    localGuests.append(cloudGuest)
                }
            }
            _ = dataStore.save(localGuests, to: Self.guestsFile)
            
            // Sync budget
            _ = dataStore.save(cloudBudget, to: Self.budgetFile)
            
            // Sync vendors
            _ = dataStore.save(cloudVendors, to: Self.vendorsFile)
            cloudKitSync.lastSyncDate = Date()
            cloudKitSync.syncError = nil
            
        } catch {
            print("Error syncing from CloudKit: \(error)")
            cloudKitSync.syncError = error.localizedDescription
        }
        
        // Also sync local guest RSVPs to CloudKit
        await syncLocalRSVPsToCloud()
    }
    
    private func syncLocalRSVPsToCloud() async {
        guard let allRSVPs = dataStore.load([GuestRSVP].self, from: Self.allGuestRSVPsFile) else { return }
        
        for rsvp in allRSVPs {
            do {
                try await cloudKitSync.upsertGuestRSVP(rsvp)
            } catch {
                print("Error saving RSVP to CloudKit: \(error)")
            }
        }
    }
    
    func bootstrap() async {
        // Load wedding details from DataStore
        if let details = dataStore.load(WeddingDetails.self, from: Self.weddingDetailsFile) {
            self.weddingDetails = details
        }
    }
    
    // MARK: - Guest Mode Functions
    
    func enterGuestMode(with code: String, rsvp: GuestRSVP, weddingId: UUID? = nil) {
        isGuestMode = true
        currentInvitationCode = code
        guestRSVP = rsvp
        guestWeddingId = weddingId
        saveGuestMode()
    }
    
    func exitGuestMode() {
        isGuestMode = false
        currentInvitationCode = nil
        guestRSVP = nil
        guestWeddingId = nil
        clearGuestMode()
    }
    
    func submitGuestRSVP(_ rsvp: GuestRSVP) {
        guestRSVP = rsvp
        _ = dataStore.save(rsvp, to: "guest_rsvp_\(rsvp.invitationCode).json")
        
        var allRSVPs = dataStore.load([GuestRSVP].self, from: Self.allGuestRSVPsFile) ?? []
        if let index = allRSVPs.firstIndex(where: { $0.invitationCode == rsvp.invitationCode }) {
            allRSVPs[index] = rsvp
        } else {
            allRSVPs.append(rsvp)
        }
        _ = dataStore.save(allRSVPs, to: Self.allGuestRSVPsFile)
        
        // Update the guest in the guests array
        updateGuest(from: rsvp)
        updateInvitationCode(from: rsvp)
        
        // Sync to iCloud
        syncRSVPToCloud(rsvp)
    }
    
    /// Update guest object when RSVP is submitted
    private func updateGuest(from rsvp: GuestRSVP) {
        // Load guests
        var guests = dataStore.load([Guest].self, from: Self.guestsFile) ?? []
        
        // Prefer invitation code, then fall back to guest name for older records.
        if let index = guests.firstIndex(where: {
            let hasMatchingCode = !$0.invitationCode.orEmpty.isEmpty && $0.invitationCode == rsvp.invitationCode
            let hasMatchingName = $0.name.caseInsensitiveCompare(rsvp.guestName) == .orderedSame
            return hasMatchingCode || hasMatchingName
        }) {
            guests[index].rsvpStatus = rsvp.rsvpStatus
            guests[index].mealChoice = rsvp.mealChoice
            guests[index].dietaryNotes = rsvp.dietaryNotes
            guests[index].partySize = rsvp.partySize
            guests[index].invitationCode = rsvp.invitationCode
            
            // Save updated guests
            _ = dataStore.save(guests, to: Self.guestsFile)
            
            Task {
                do {
                    try await self.saveGuestToCloud(guests[index])
                } catch {
                    print("Failed to sync RSVP-updated guest to CloudKit: \(error)")
                }
            }
        } else if !rsvp.guestName.isEmpty {
            let guest = Guest(
                name: rsvp.guestName,
                rsvpStatus: rsvp.rsvpStatus,
                mealChoice: rsvp.mealChoice,
                dietaryNotes: rsvp.dietaryNotes,
                partySize: rsvp.partySize,
                invitationCode: rsvp.invitationCode
            )
            guests.append(guest)
            _ = dataStore.save(guests, to: Self.guestsFile)
            
            Task {
                do {
                    try await self.saveGuestToCloud(guest)
                } catch {
                    print("Failed to sync new RSVP guest to CloudKit: \(error)")
                }
            }
        }
    }
    
    /// Save partial RSVP progress and sync to CloudKit after each step
    func updateGuestRSVPProgress(_ rsvp: GuestRSVP) {
        // Update current guest RSVP
        guestRSVP = rsvp
        
        // Save locally
        _ = dataStore.save(rsvp, to: "guest_rsvp_\(rsvp.invitationCode).json")
        
        // Update in all_guest_rsvps.json for co-planner visibility
        var allRSVPs = dataStore.load([GuestRSVP].self, from: Self.allGuestRSVPsFile) ?? []
        if let index = allRSVPs.firstIndex(where: { $0.invitationCode == rsvp.invitationCode }) {
            allRSVPs[index] = rsvp
        } else {
            allRSVPs.append(rsvp)
        }
        _ = dataStore.save(allRSVPs, to: Self.allGuestRSVPsFile)
        updateInvitationCode(from: rsvp)
        
        // Sync to CloudKit (upsert - updates existing or creates new)
        Task {
            do {
                try await cloudKitSync.upsertGuestRSVP(rsvp)
                print("✅ Guest RSVP progress synced to CloudKit")
            } catch {
                print("❌ Failed to sync guest RSVP progress: \(error)")
            }
        }
    }
    
    private func syncRSVPToCloud(_ rsvp: GuestRSVP) {
        Task {
            do {
                try await cloudKitSync.upsertGuestRSVP(rsvp)
            } catch {
                print("Error saving RSVP to iCloud: \(error.localizedDescription)")
            }
        }
    }
    
    private func updateInvitationCode(from rsvp: GuestRSVP) {
        var invitationCodes = dataStore.load([InvitationCode].self, from: "invitation_codes.json") ?? []
        guard let index = invitationCodes.firstIndex(where: { $0.code == rsvp.invitationCode }) else { return }
        
        invitationCodes[index].guestName = rsvp.guestName
        invitationCodes[index].rsvpStatus = rsvp.rsvpStatus
        invitationCodes[index].mealChoice = rsvp.mealChoice
        invitationCodes[index].dietaryNotes = rsvp.dietaryNotes
        invitationCodes[index].partySize = rsvp.partySize
        let updatedInvitation = invitationCodes[index]
        _ = dataStore.save(invitationCodes, to: "invitation_codes.json")
        
        Task {
            do {
                try await self.cloudKitSync.saveInvitationCode(updatedInvitation)
            } catch {
                print("Failed to sync invitation code update to CloudKit: \(error)")
            }
        }
    }
    
    func setGuestCheckIn(for guestID: UUID, checkedIn: Bool) {
        var guests = dataStore.load([Guest].self, from: Self.guestsFile) ?? []
        guard let index = guests.firstIndex(where: { $0.id == guestID }) else { return }
        
        guests[index].checkedInAt = checkedIn ? (guests[index].checkedInAt ?? Date()) : nil
        _ = dataStore.save(guests, to: Self.guestsFile)
        
        Task {
            do {
                try await self.saveGuestToCloud(guests[index])
            } catch {
                print("Failed to sync guest check-in to CloudKit: \(error)")
            }
        }
    }
    
    private func saveGuestMode() {
        let data: [String: String?] = [
            "invitationCode": currentInvitationCode,
            "guestRSVP": nil,
            "guestWeddingId": guestWeddingId?.uuidString
        ]
        if let encoded = try? JSONEncoder().encode(data) {
            UserDefaults.standard.set(encoded, forKey: "guestMode")
        }
    }
    
    private func loadGuestMode() {
        // Default to host mode unless guest mode data is found
        isGuestMode = false
        currentInvitationCode = nil
        guestRSVP = nil
        guestWeddingId = nil
        
        if let data = UserDefaults.standard.data(forKey: "guestMode"),
           let decoded = try? JSONDecoder().decode([String: String?].self, from: data),
           let code = decoded["invitationCode"] ?? nil {
            currentInvitationCode = code
            isGuestMode = true
            if let guestWeddingIdString = decoded["guestWeddingId"] ?? nil {
                guestWeddingId = UUID(uuidString: guestWeddingIdString)
            }
            
            if let rsvpData = dataStore.load(GuestRSVP.self, from: "guest_rsvp_\(code).json") {
                guestRSVP = rsvpData
            } else if let invitationCodes = dataStore.load([InvitationCode].self, from: "invitation_codes.json"),
                      let invitation = invitationCodes.first(where: { $0.code == code }) {
                guestRSVP = GuestRSVP(
                    invitationCode: code,
                    guestName: invitation.guestName ?? "",
                    rsvpStatus: invitation.rsvpStatus ?? .noResponse,
                    mealChoice: invitation.mealChoice,
                    dietaryNotes: invitation.dietaryNotes,
                    partySize: invitation.partySize
                )
            }
        }
        
        // Also load wedding details from storage
        if let savedDetails = dataStore.load(WeddingDetails.self, from: Self.weddingDetailsFile) {
            self.weddingDetails = savedDetails
        }
    }
    
    private func clearGuestMode() {
        UserDefaults.standard.removeObject(forKey: "guestMode")
    }
    
    // MARK: - Co-Planner Functions
    
    func generateCoPlannerCode() async throws -> String {
        if weddingId == nil {
            self.weddingId = UUID()
        }
        guard let weddingId = self.weddingId else {
            throw NSError(domain: "AppState", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to generate wedding ID"])
        }
        return try await cloudKitSync.generateCoPlannerCode(weddingId: weddingId)
    }
    
    func joinAsCoPlanner(with code: String) async throws -> Bool {
        guard let weddingIdString = try await cloudKitSync.validateCoPlannerCode(code) else {
            return false
        }
        
        guard let weddingId = UUID(uuidString: weddingIdString) else {
            return false
        }
        
        self.weddingId = weddingId
        self.isCoPlanner = true
        
        // Fetch wedding data from CloudKit
        let (wedding, guests, budget, vendors) = try await cloudKitSync.syncAllData(weddingId: weddingId)
        
        if let wedding = wedding {
            self.weddingDetails = wedding
        }
        
        _ = dataStore.save(guests, to: Self.guestsFile)
        _ = dataStore.save(budget, to: Self.budgetFile)
        _ = dataStore.save(vendors, to: Self.vendorsFile)
        
        return true
    }
    
    // Save guest data to CloudKit (for co-planner sync)
    func saveGuestToCloud(_ guest: Guest) async throws {
        guard let weddingId = weddingId else { return }
        try await cloudKitSync.saveGuests([guest], weddingId: weddingId)
    }
    
    // Save budget to CloudKit
    func saveBudgetToCloud(_ categories: [BudgetCategory]) async throws {
        guard let weddingId = weddingId else { return }
        try await cloudKitSync.saveBudget(categories, weddingId: weddingId)
    }
    
    // Save vendors to CloudKit
    func saveVendorsToCloud(_ vendors: [Vendor]) async throws {
        guard let weddingId = weddingId else { return }
        try await cloudKitSync.saveVendors(vendors, weddingId: weddingId)
    }
    
    func saveInvitationCodeToCloud(_ invitation: InvitationCode) async throws {
        try await cloudKitSync.saveInvitationCode(invitation)
    }
    
    func fetchInvitationCodeFromCloud(_ code: String) async throws -> InvitationCode? {
        try await cloudKitSync.fetchInvitationCode(code)
    }
    
    func refreshFromCloudKit() async {
        await syncFromCloudKit()
    }
}

private extension Optional where Wrapped == String {
    var orEmpty: String {
        self ?? ""
    }
}
