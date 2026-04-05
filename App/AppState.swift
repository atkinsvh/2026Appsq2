//
//  AppState.swift
//  VowPlanner
//
//  FIXED:
//    BUG-02 — userId not persisted on first generation (didSet skipped in init)
//    BUG-03 — mergePublicRSVPs name-only match causes cross-guest data corruption
//    BUG-04 — saveGuestMode stored a meaningless nil key for guestRSVP

import Foundation
import SwiftUI
import CloudKit

private enum PendingGuestSyncKind: String, Codable {
    case guest
    case invitationCode
    case rsvp
}

private struct PendingGuestSyncOperation: Identifiable, Codable {
    let id: UUID
    let kind: PendingGuestSyncKind
    let weddingId: UUID?
    let guest: Guest?
    let invitation: InvitationCode?
    let rsvp: GuestRSVP?
    let createdAt: Date

    init(
        id: UUID = UUID(),
        kind: PendingGuestSyncKind,
        weddingId: UUID? = nil,
        guest: Guest? = nil,
        invitation: InvitationCode? = nil,
        rsvp: GuestRSVP? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.kind = kind
        self.weddingId = weddingId
        self.guest = guest
        self.invitation = invitation
        self.rsvp = rsvp
        self.createdAt = createdAt
    }

    var dedupeKey: String {
        switch kind {
        case .guest:
            return "guest-\(guest?.id.uuidString ?? "unknown")"
        case .invitationCode:
            return "invitation-\(invitation?.code ?? "unknown")"
        case .rsvp:
            return "rsvp-\(rsvp?.invitationCode ?? "unknown")"
        }
    }
}

enum GuestCodeValidationError: LocalizedError {
    case invalidFormat
    case notFound

    var errorDescription: String? {
        switch self {
        case .invalidFormat:
            return "Please enter a valid 6-character invitation code."
        case .notFound:
            return "We couldn't verify that guest code. Ask the couple to confirm it and try again."
        }
    }
}

@MainActor
class AppState: ObservableObject {
    private static let onboardingCompletedKey = "AppState.onboardingCompleted"
    private static let weddingIdKey = "AppState.weddingId"
    private static let userIdKey = "AppState.userId"
    private static let isCoPlannerKey = "AppState.isCoPlanner"
    private static let guestWeddingIdKey = "AppState.guestWeddingId"
    private static let isGuestAccessOnlyKey = "AppState.isGuestAccessOnly"
    private static let guestModeDefaultsKey = "guestMode"
    private static let weddingDetailsFile = "wedding_details.json"
    private static let guestsFile = "guests.json"
    private static let budgetFile = "budget_categories.json"
    private static let vendorsFile = "vendors.json"
    private static let invitationCodesFile = "invitation_codes.json"
    private static let allGuestRSVPsFile = "all_guest_rsvps.json"
    private static let pendingGuestSyncsFile = "pending_guest_syncs.json"

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
    @Published var isGuestAccessOnly: Bool = false {
        didSet {
            UserDefaults.standard.set(isGuestAccessOnly, forKey: Self.isGuestAccessOnlyKey)
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
    @Published var userId: UUID {
        didSet {
            UserDefaults.standard.set(userId.uuidString, forKey: Self.userIdKey)
        }
    }
    @Published var weddingMemberships: [WeddingSummary] = []

    private var activeWeddingId: UUID? {
        weddingId ?? guestWeddingId
    }

    // MARK: - Init
    // BUG-02 FIX: `didSet` is NOT called during `init`, so a newly generated UUID
    // must be explicitly saved to UserDefaults rather than relying on the observer.
    init() {
        if let savedUserId = UserDefaults.standard.string(forKey: Self.userIdKey),
           let parsed = UUID(uuidString: savedUserId) {
            userId = parsed
        } else {
            let newId = UUID()
            userId = newId
            // Explicit save — didSet does not fire during initialisation.
            UserDefaults.standard.set(newId.uuidString, forKey: Self.userIdKey)
        }

        onboardingCompleted = UserDefaults.standard.bool(forKey: Self.onboardingCompletedKey)
        isCoPlanner = UserDefaults.standard.bool(forKey: Self.isCoPlannerKey)
        isGuestAccessOnly = UserDefaults.standard.bool(forKey: Self.isGuestAccessOnlyKey)

        if let weddingIdString = UserDefaults.standard.string(forKey: Self.weddingIdKey) {
            weddingId = UUID(uuidString: weddingIdString)
        }
        if let guestWeddingIdString = UserDefaults.standard.string(forKey: Self.guestWeddingIdKey) {
            guestWeddingId = UUID(uuidString: guestWeddingIdString)
        }

        loadGuestMode()

        if !isGuestMode, !isGuestAccessOnly, weddingId != nil {
            Task {
                await syncFromCloudKit()
            }
        }

        fetchWeddingsForCurrentUser()

        Task {
            await flushPendingGuestSyncOperations()
        }
    }

    private func syncFromCloudKit() async {
        guard let weddingId = weddingId else {
            await flushPendingGuestSyncOperations()
            return
        }

        do {
            let (cloudWedding, cloudGuests, cloudBudget, cloudVendors) = try await cloudKitSync.syncAllData(weddingId: weddingId)

            if let cloudWedding = cloudWedding {
                self.weddingDetails = cloudWedding
            }

            var localGuests = dataStore.load([Guest].self, from: Self.guestsFile) ?? []
            for cloudGuest in cloudGuests {
                if let index = localGuests.firstIndex(where: { $0.id == cloudGuest.id }) {
                    localGuests[index] = cloudGuest
                } else {
                    localGuests.append(cloudGuest)
                }
            }

            let invitationCodesForSync = Set(localGuests.compactMap(\.invitationCode).filter { !$0.isEmpty })
            if !invitationCodesForSync.isEmpty {
                var allRSVPs: [GuestRSVP] = []
                for code in invitationCodesForSync {
                    let rsvps = try await cloudKitSync.fetchGuestRSVPs(for: code)
                    allRSVPs.append(contentsOf: rsvps)
                }
                mergePublicRSVPs(allRSVPs, into: &localGuests)
            }

            _ = dataStore.save(localGuests, to: Self.guestsFile)
            _ = dataStore.save(cloudBudget, to: Self.budgetFile)
            _ = dataStore.save(cloudVendors, to: Self.vendorsFile)
            cloudKitSync.lastSyncDate = Date()
            cloudKitSync.syncError = nil

        } catch {
            print("Error syncing from CloudKit: \(error)")
            cloudKitSync.syncError = error.localizedDescription
        }

        await syncLocalRSVPsToCloud()
        await flushPendingGuestSyncOperations()
    }

    private func syncLocalRSVPsToCloud() async {
        guard let allRSVPs = dataStore.load([GuestRSVP].self, from: Self.allGuestRSVPsFile) else { return }

        for rsvp in allRSVPs {
            do {
                try await cloudKitSync.upsertGuestRSVP(rsvp)
                removePendingGuestSync(kind: .rsvp, matchingCode: rsvp.invitationCode)
            } catch {
                enqueuePendingGuestSync(.init(kind: .rsvp, rsvp: rsvp))
                print("Error saving RSVP to CloudKit: \(error)")
            }
        }
    }

    func bootstrap() async {
        if let details = dataStore.load(WeddingDetails.self, from: Self.weddingDetailsFile) {
            self.weddingDetails = details
        }
        await flushPendingGuestSyncOperations()
    }

    // MARK: - Guest Mode Functions

    func normalizeInvitationCode(_ code: String) -> String {
        InvitationCode.normalize(code)
    }

    func verifyGuestInvitationCode(_ rawCode: String) async throws -> InvitationCode {
        let cleanCode = normalizeInvitationCode(rawCode)
        guard cleanCode.count == 6 else {
            throw GuestCodeValidationError.invalidFormat
        }

        if let invitation = cachedInvitation(for: cleanCode) {
            return invitation
        }

        if let invitation = try await fetchInvitationCodeFromCloud(cleanCode) {
            cacheInvitation(invitation)
            return invitation
        }

        throw GuestCodeValidationError.notFound
    }

    func enterGuestMode(with invitation: InvitationCode) {
        let code = normalizeInvitationCode(invitation.code)
        let rsvp = GuestRSVP(
            invitationCode: code,
            guestName: invitation.guestName ?? "",
            rsvpStatus: invitation.rsvpStatus ?? .noResponse,
            mealChoice: invitation.mealChoice,
            dietaryNotes: invitation.dietaryNotes,
            partySize: invitation.partySize
        )

        cacheInvitation(invitation)
        weddingDetails = WeddingDetails(
            coupleNames: invitation.coupleNames,
            date: invitation.weddingDate,
            location: invitation.weddingLocation,
            mealOptions: invitation.mealChoice != nil ? [invitation.mealChoice!] : []
        )
        isGuestAccessOnly = true
        onboardingCompleted = true
        enterGuestMode(with: code, rsvp: rsvp, weddingId: invitation.weddingId)
    }

    func enterGuestMode(with code: String, rsvp: GuestRSVP, weddingId: UUID? = nil) {
        isGuestMode = true
        isGuestAccessOnly = true
        currentInvitationCode = normalizeInvitationCode(code)
        guestRSVP = rsvp
        guestWeddingId = weddingId
        saveGuestMode()
    }

    // MARK: - BUG-03 FIX: mergePublicRSVPs
    // Previous logic used `nameMatch` alone (without any code check), which meant
    // two guests with the same name would silently overwrite each other's RSVP data.
    // The fix: name-only matching is only accepted when BOTH the RSVP and the guest
    // record lack invitation codes — i.e., it is genuinely the only identifier available.
    private func mergePublicRSVPs(_ rsvps: [GuestRSVP], into guests: inout [Guest]) {
        for rsvp in rsvps {
            let normalizedCode = normalizeInvitationCode(rsvp.invitationCode)

            if let guestIndex = guests.firstIndex(where: { guest in
                // Primary match: invitation code (most specific, use whenever present)
                let guestCode = normalizeInvitationCode(guest.invitationCode.orEmpty)
                let codeMatch = !normalizedCode.isEmpty && guestCode == normalizedCode

                // Fallback match: name, only when neither side has a code
                let guestLacksCode = guestCode.isEmpty
                let rsvpLacksCode = normalizedCode.isEmpty
                let nameMatch = guestLacksCode && rsvpLacksCode
                    && guest.name.caseInsensitiveCompare(rsvp.guestName) == .orderedSame

                return codeMatch || nameMatch
            }) {
                guests[guestIndex].rsvpStatus = rsvp.rsvpStatus
                guests[guestIndex].mealChoice = rsvp.mealChoice
                guests[guestIndex].dietaryNotes = rsvp.dietaryNotes
                guests[guestIndex].partySize = rsvp.partySize
                if !normalizedCode.isEmpty {
                    guests[guestIndex].invitationCode = normalizedCode
                }
            } else if !rsvp.guestName.isEmpty {
                guests.append(
                    Guest(
                        name: rsvp.guestName,
                        rsvpStatus: rsvp.rsvpStatus,
                        mealChoice: rsvp.mealChoice,
                        dietaryNotes: rsvp.dietaryNotes,
                        partySize: rsvp.partySize,
                        invitationCode: normalizedCode.isEmpty ? nil : normalizedCode
                    )
                )
            }
        }
    }

    func returnToGuestCodeEntry() {
        isGuestMode = false
        currentInvitationCode = nil
        guestRSVP = nil
        clearGuestMode()
        isGuestAccessOnly = true
        onboardingCompleted = true
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

        updateGuest(from: rsvp)
        updateInvitationCode(from: rsvp)
        syncRSVPToCloud(rsvp)
    }

    private func updateGuest(from rsvp: GuestRSVP) {
        var guests = dataStore.load([Guest].self, from: Self.guestsFile) ?? []

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
            _ = dataStore.save(guests, to: Self.guestsFile)

            Task {
                do {
                    try await self.saveGuestToCloud(guests[index])
                    self.removePendingGuestSync(kind: .guest, guestID: guests[index].id)
                } catch {
                    self.enqueuePendingGuestSync(.init(kind: .guest, weddingId: self.activeWeddingId, guest: guests[index]))
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
                    self.removePendingGuestSync(kind: .guest, guestID: guest.id)
                } catch {
                    self.enqueuePendingGuestSync(.init(kind: .guest, weddingId: self.activeWeddingId, guest: guest))
                    print("Failed to sync new RSVP guest to CloudKit: \(error)")
                }
            }
        }
    }

    func updateGuestRSVPProgress(_ rsvp: GuestRSVP) {
        guestRSVP = rsvp
        _ = dataStore.save(rsvp, to: "guest_rsvp_\(rsvp.invitationCode).json")

        var allRSVPs = dataStore.load([GuestRSVP].self, from: Self.allGuestRSVPsFile) ?? []
        if let index = allRSVPs.firstIndex(where: { $0.invitationCode == rsvp.invitationCode }) {
            allRSVPs[index] = rsvp
        } else {
            allRSVPs.append(rsvp)
        }
        _ = dataStore.save(allRSVPs, to: Self.allGuestRSVPsFile)
        updateInvitationCode(from: rsvp)

        Task {
            do {
                try await cloudKitSync.upsertGuestRSVP(rsvp)
                removePendingGuestSync(kind: .rsvp, matchingCode: rsvp.invitationCode)
                print("✅ Guest RSVP progress synced to CloudKit")
            } catch {
                enqueuePendingGuestSync(.init(kind: .rsvp, rsvp: rsvp))
                print("❌ Failed to sync guest RSVP progress: \(error)")
            }
        }
    }

    private func syncRSVPToCloud(_ rsvp: GuestRSVP) {
        Task {
            do {
                try await cloudKitSync.upsertGuestRSVP(rsvp)
                removePendingGuestSync(kind: .rsvp, matchingCode: rsvp.invitationCode)
            } catch {
                enqueuePendingGuestSync(.init(kind: .rsvp, rsvp: rsvp))
                print("Error saving RSVP to iCloud: \(error.localizedDescription)")
            }
        }
    }

    private func updateInvitationCode(from rsvp: GuestRSVP) {
        var invitationCodes = dataStore.load([InvitationCode].self, from: Self.invitationCodesFile) ?? []
        guard let index = invitationCodes.firstIndex(where: { $0.code == rsvp.invitationCode }) else { return }

        invitationCodes[index].guestName = rsvp.guestName
        invitationCodes[index].rsvpStatus = rsvp.rsvpStatus
        invitationCodes[index].mealChoice = rsvp.mealChoice
        invitationCodes[index].dietaryNotes = rsvp.dietaryNotes
        invitationCodes[index].partySize = rsvp.partySize
        let updatedInvitation = invitationCodes[index]
        _ = dataStore.save(invitationCodes, to: Self.invitationCodesFile)

        Task {
            do {
                try await self.cloudKitSync.saveInvitationCode(updatedInvitation)
                self.removePendingGuestSync(kind: .invitationCode, matchingCode: updatedInvitation.code)
            } catch {
                self.enqueuePendingGuestSync(.init(kind: .invitationCode, invitation: updatedInvitation))
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
                self.removePendingGuestSync(kind: .guest, guestID: guestID)
            } catch {
                self.enqueuePendingGuestSync(.init(kind: .guest, weddingId: self.activeWeddingId, guest: guests[index]))
                print("Failed to sync guest check-in to CloudKit: \(error)")
            }
        }
    }

    // MARK: - BUG-04 FIX: saveGuestMode
    // The old version stored `"guestRSVP": nil` as a key in the dictionary, which
    // was never read back and created the false impression that guestRSVP persisted
    // through this path (it persists via its own file, not via this dictionary).
    // Removed the dead key to make intent explicit.
    private func saveGuestMode() {
        let data: [String: String?] = [
            "invitationCode": currentInvitationCode,
            "guestWeddingId": guestWeddingId?.uuidString
        ]
        if let encoded = try? JSONEncoder().encode(data) {
            UserDefaults.standard.set(encoded, forKey: Self.guestModeDefaultsKey)
        }
    }

    private func loadGuestMode() {
        isGuestMode = false
        currentInvitationCode = nil
        guestRSVP = nil
        guestWeddingId = nil

        if let data = UserDefaults.standard.data(forKey: Self.guestModeDefaultsKey),
           let decoded = try? JSONDecoder().decode([String: String?].self, from: data),
           let code = decoded["invitationCode"] ?? nil {
            let normalizedCode = normalizeInvitationCode(code)
            currentInvitationCode = normalizedCode
            isGuestMode = true
            isGuestAccessOnly = true

            if let guestWeddingIdString = decoded["guestWeddingId"] ?? nil {
                guestWeddingId = UUID(uuidString: guestWeddingIdString)
            }

            if let rsvpData = dataStore.load(GuestRSVP.self, from: "guest_rsvp_\(normalizedCode).json") {
                guestRSVP = rsvpData
            } else if let invitation = cachedInvitation(for: normalizedCode) {
                hydrateGuestRSVP(from: invitation)
            }
        }

        if let savedDetails = dataStore.load(WeddingDetails.self, from: Self.weddingDetailsFile) {
            self.weddingDetails = savedDetails
        }
    }

    private func clearGuestMode() {
        UserDefaults.standard.removeObject(forKey: Self.guestModeDefaultsKey)
    }

    // MARK: - Co-Planner Functions

    func generateCoPlannerCode() async throws -> String {
        if weddingId == nil {
            self.weddingId = UUID()
            if let weddingId = weddingId {
                registerWeddingMembership(
                    weddingId: weddingId,
                    role: .host,
                    details: weddingDetails
                )
            }
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
        self.isGuestAccessOnly = false

        let (wedding, guests, budget, vendors) = try await cloudKitSync.syncAllData(weddingId: weddingId)

        if let wedding = wedding {
            self.weddingDetails = wedding
        }

        _ = dataStore.save(guests, to: Self.guestsFile)
        _ = dataStore.save(budget, to: Self.budgetFile)
        _ = dataStore.save(vendors, to: Self.vendorsFile)
        registerWeddingMembership(
            weddingId: weddingId,
            role: .coplanner,
            details: self.weddingDetails
        )

        return true
    }

    // MARK: - User <> Wedding Memberships

    func fetchWeddingsForCurrentUser() {
        APIClient.shared.fetchWeddings(for: userId) { [weak self] weddings in
            guard let self else { return }
            Task { @MainActor in
                self.weddingMemberships = weddings
                if self.weddingId == nil, let first = weddings.first {
                    await self.switchWedding(to: first.weddingId)
                }
            }
        }
    }

    @discardableResult
    func registerWeddingMembership(
        weddingId: UUID,
        role: WeddingRole,
        details: WeddingDetails
    ) -> UserWeddingMembership {
        let fileName = membershipFileName(for: userId)
        var memberships = dataStore.load([UserWeddingMembership].self, from: fileName) ?? []

        let entry = UserWeddingMembership(
            userId: userId,
            weddingId: weddingId,
            role: role,
            coupleNames: details.coupleNames,
            weddingDate: details.date,
            weddingLocation: details.location
        )

        if let index = memberships.firstIndex(where: { $0.weddingId == weddingId }) {
            memberships[index] = entry
        } else {
            memberships.append(entry)
        }

        _ = dataStore.save(memberships, to: fileName)
        fetchWeddingsForCurrentUser()
        return entry
    }

    func updateCurrentWeddingMembership(with details: WeddingDetails) {
        guard let weddingId else { return }
        let role: WeddingRole = isCoPlanner ? .coplanner : .host
        registerWeddingMembership(weddingId: weddingId, role: role, details: details)
    }

    func switchWedding(to selectedWeddingId: UUID) async {
        weddingId = selectedWeddingId
        if let selected = weddingMemberships.first(where: { $0.weddingId == selectedWeddingId }) {
            isCoPlanner = selected.role == .coplanner
        }
        await syncFromCloudKit()
    }

    private func membershipFileName(for userId: UUID) -> String {
        "user_wedding_memberships_\(userId.uuidString.lowercased()).json"
    }

    func saveGuestToCloud(_ guest: Guest) async throws {
        guard let activeWeddingId else { return }
        try await cloudKitSync.saveGuests([guest], weddingId: activeWeddingId)
    }

    func saveBudgetToCloud(_ categories: [BudgetCategory]) async throws {
        guard let weddingId = weddingId else { return }
        try await cloudKitSync.saveBudget(categories, weddingId: weddingId)
    }

    func saveVendorsToCloud(_ vendors: [Vendor]) async throws {
        guard let weddingId = weddingId else { return }
        try await cloudKitSync.saveVendors(vendors, weddingId: weddingId)
    }

    func saveInvitationCodeToCloud(_ invitation: InvitationCode) async throws {
        try await cloudKitSync.saveInvitationCode(invitation)
        removePendingGuestSync(kind: .invitationCode, matchingCode: invitation.code)
    }

    func fetchInvitationCodeFromCloud(_ code: String) async throws -> InvitationCode? {
        try await cloudKitSync.fetchInvitationCode(normalizeInvitationCode(code))
    }

    func refreshFromCloudKit() async {
        await syncFromCloudKit()
    }

    // MARK: - Guest Cache + Pending Sync

    private func cachedInvitation(for code: String) -> InvitationCode? {
        let cleanCode = normalizeInvitationCode(code)
        guard let invitationCodes = dataStore.load([InvitationCode].self, from: Self.invitationCodesFile) else {
            return nil
        }
        return invitationCodes.first(where: { $0.code == cleanCode })
    }

    private func cacheInvitation(_ invitation: InvitationCode) {
        var invitationCodes = dataStore.load([InvitationCode].self, from: Self.invitationCodesFile) ?? []
        if let index = invitationCodes.firstIndex(where: { $0.code == invitation.code }) {
            invitationCodes[index] = invitation
        } else {
            invitationCodes.append(invitation)
        }
        _ = dataStore.save(invitationCodes, to: Self.invitationCodesFile)
    }

    private func hydrateGuestRSVP(from invitation: InvitationCode) {
        weddingDetails = WeddingDetails(
            coupleNames: invitation.coupleNames,
            date: invitation.weddingDate,
            location: invitation.weddingLocation
        )
        guestRSVP = GuestRSVP(
            invitationCode: invitation.code,
            guestName: invitation.guestName ?? "",
            rsvpStatus: invitation.rsvpStatus ?? .noResponse,
            mealChoice: invitation.mealChoice,
            dietaryNotes: invitation.dietaryNotes,
            partySize: invitation.partySize
        )
        if guestWeddingId == nil {
            guestWeddingId = invitation.weddingId
        }
    }

    private func loadPendingGuestSyncOperations() -> [PendingGuestSyncOperation] {
        dataStore.load([PendingGuestSyncOperation].self, from: Self.pendingGuestSyncsFile) ?? []
    }

    private func savePendingGuestSyncOperations(_ operations: [PendingGuestSyncOperation]) {
        _ = dataStore.save(operations, to: Self.pendingGuestSyncsFile)
    }

    private func enqueuePendingGuestSync(_ operation: PendingGuestSyncOperation) {
        var operations = loadPendingGuestSyncOperations()
        operations.removeAll { $0.dedupeKey == operation.dedupeKey }
        operations.append(operation)
        savePendingGuestSyncOperations(operations.sorted { $0.createdAt < $1.createdAt })
    }

    private func removePendingGuestSync(kind: PendingGuestSyncKind, matchingCode: String? = nil, guestID: UUID? = nil) {
        let cleanCode = matchingCode.map(normalizeInvitationCode)
        let filtered = loadPendingGuestSyncOperations().filter { operation in
            guard operation.kind == kind else { return true }
            switch kind {
            case .guest:
                return operation.guest?.id != guestID
            case .invitationCode:
                return operation.invitation?.code != cleanCode
            case .rsvp:
                return operation.rsvp?.invitationCode != cleanCode
            }
        }
        savePendingGuestSyncOperations(filtered)
    }

    private func flushPendingGuestSyncOperations() async {
        guard cloudKitSync.isOnline else { return }

        var remaining: [PendingGuestSyncOperation] = []
        for operation in loadPendingGuestSyncOperations() {
            do {
                switch operation.kind {
                case .guest:
                    guard let guest = operation.guest,
                          let weddingId = operation.weddingId ?? activeWeddingId else {
                        continue
                    }
                    try await cloudKitSync.saveGuests([guest], weddingId: weddingId)
                case .invitationCode:
                    guard let invitation = operation.invitation else { continue }
                    try await cloudKitSync.saveInvitationCode(invitation)
                case .rsvp:
                    guard let rsvp = operation.rsvp else { continue }
                    try await cloudKitSync.upsertGuestRSVP(rsvp)
                }
            } catch {
                remaining.append(operation)
                print("Deferred guest sync still pending: \(error.localizedDescription)")
            }
        }

        savePendingGuestSyncOperations(remaining)
    }
}

private extension Optional where Wrapped == String {
    var orEmpty: String {
        self ?? ""
    }
}
