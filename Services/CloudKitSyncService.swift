import Foundation
import CloudKit
import Network

@MainActor
class CloudKitSyncService: ObservableObject {
    private let container: CKContainer
    private let privateDatabase: CKDatabase
    private let publicDatabase: CKDatabase
    
    @Published var isOnline = true
    @Published var isSyncing = false
    @Published var lastSyncDate: Date?
    @Published var syncError: String?
    
    private let networkMonitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "NetworkMonitor")
    
    init() {
        container = CKContainer(identifier: "iCloud.com.goodvibez.vowplanner")
        privateDatabase = container.privateCloudDatabase
        publicDatabase = container.publicCloudDatabase
        
        setupNetworkMonitoring()
    }
    
    private func setupNetworkMonitoring() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                self?.isOnline = path.status == .satisfied
            }
        }
        networkMonitor.start(queue: monitorQueue)
    }
    
    private func fetchOrCreateRecord(
        recordType: String,
        recordID: CKRecord.ID,
        in database: CKDatabase
    ) async throws -> CKRecord {
        do {
            return try await database.record(for: recordID)
        } catch let error as CKError where error.code == .unknownItem {
            return CKRecord(recordType: recordType, recordID: recordID)
        } catch {
            throw error
        }
    }
    
    private func normalizedRecordKey(_ value: String) -> String {
        let allowed = CharacterSet.alphanumerics
        let normalizedScalars = value
            .lowercased()
            .unicodeScalars
            .map { allowed.contains($0) ? Character($0) : "-" }
        let raw = String(normalizedScalars)
        return raw
            .replacingOccurrences(of: "--+", with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
    }
    
    private func weddingRecordID(for weddingId: UUID) -> CKRecord.ID {
        CKRecord.ID(recordName: "wedding-\(weddingId.uuidString.lowercased())")
    }
    
    private func guestRecordID(for guestId: UUID) -> CKRecord.ID {
        CKRecord.ID(recordName: "guest-\(guestId.uuidString.lowercased())")
    }
    
    private func budgetRecordID(for categoryId: UUID) -> CKRecord.ID {
        CKRecord.ID(recordName: "budget-\(categoryId.uuidString.lowercased())")
    }
    
    private func vendorRecordID(for vendorId: UUID) -> CKRecord.ID {
        CKRecord.ID(recordName: "vendor-\(vendorId.uuidString.lowercased())")
    }
    
    private func coPlannerRecordID(for code: String) -> CKRecord.ID {
        CKRecord.ID(recordName: "coplanner-\(InvitationCode.normalize(code))")
    }
    
    private func guestRSVPRecordID(for rsvp: GuestRSVP) -> CKRecord.ID {
        let guestKey = normalizedRecordKey(rsvp.guestName)
        return CKRecord.ID(recordName: "guest-rsvp-\(InvitationCode.normalize(rsvp.invitationCode))-\(guestKey)")
    }
    
    private func invitationCodeRecordID(for code: String) -> CKRecord.ID {
        CKRecord.ID(recordName: "invitation-\(InvitationCode.normalize(code))")
    }
    
    private func eventPhotoRecordID(for photoId: UUID) -> CKRecord.ID {
        CKRecord.ID(recordName: "event-photo-\(photoId.uuidString.lowercased())")
    }
    
    // MARK: - Retry Logic
    
    func saveWithRetry<T>(_ operation: () async throws -> T, maxRetries: Int = 3) async throws -> T {
        var lastError: Error?
        
        for attempt in 1...maxRetries {
            do {
                let result = try await operation()
                syncError = nil
                return result
            } catch {
                lastError = error
                print("CloudKitSync: Attempt \(attempt) failed - \(error.localizedDescription)")
                
                if attempt < maxRetries {
                    let delay = Double(attempt) * 1.0
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
            }
        }
        
        syncError = lastError?.localizedDescription ?? "Unknown sync error"
        throw lastError ?? SyncError.unknown
    }
    
    enum SyncError: LocalizedError {
        case noNetwork
        case notAuthenticated
        case unknown
        
        var errorDescription: String? {
            switch self {
            case .noNetwork: return "No internet connection"
            case .notAuthenticated: return "Please sign in to iCloud"
            case .unknown: return "An unknown error occurred"
            }
        }
    }
    
    // MARK: - Check iCloud Status
    
    func checkAccountStatus() async -> Bool {
        do {
            let status = try await container.accountStatus()
            return status == .available
        } catch {
            print("CloudKitSync: Account status check failed - \(error.localizedDescription)")
            return false
        }
    }
    
    // MARK: - Wedding Data
    
    func saveWedding(_ wedding: WeddingDetails, weddingId: UUID) async throws -> String {
        print("CloudKitSync: Attempting to save Wedding record...")
        
        guard isOnline else {
            throw SyncError.noNetwork
        }
        
        let recordID = weddingRecordID(for: weddingId)
        let record = try await fetchOrCreateRecord(recordType: "Wedding", recordID: recordID, in: privateDatabase)
        record["weddingId"] = weddingId.uuidString
        record["coupleNames"] = wedding.coupleNames
        record["date"] = wedding.date as CKRecordValue
        record["location"] = wedding.location
        record["mealOptions"] = wedding.mealOptions as CKRecordValue
        let questionsData = try JSONEncoder().encode(wedding.customQuestions)
        record["customQuestions"] = questionsData as CKRecordValue
        
        do {
            let savedRecord = try await saveWithRetry {
                try await self.privateDatabase.save(record)
            }
            print("CloudKitSync: ✅ Wedding saved successfully - \(savedRecord.recordID.recordName)")
            lastSyncDate = Date()
            return savedRecord.recordID.recordName
        } catch {
            print("CloudKitSync: ❌ Wedding save failed: \(error.localizedDescription)")
            throw error
        }
    }
    
    func fetchWedding(weddingId: UUID) async throws -> WeddingDetails? {
        guard isOnline else {
            throw SyncError.noNetwork
        }
        
        do {
            let record = try await privateDatabase.record(for: weddingRecordID(for: weddingId))
            let coupleNames = record["coupleNames"] as? String ?? ""
            let date = record["date"] as? Date ?? Date()
            let location = record["location"] as? String ?? ""
            let mealOptions = record["mealOptions"] as? [String]
            let customQuestions: [RSVPQuestion]?
            if let questionsData = record["customQuestions"] as? Data {
                customQuestions = try? JSONDecoder().decode([RSVPQuestion].self, from: questionsData)
            } else if let legacyQuestions = record["customQuestions"] as? [String] {
                customQuestions = legacyQuestions.enumerated().map { index, title in
                    RSVPQuestion(title: title, type: .text, displayOrder: index)
                }
            } else {
                customQuestions = nil
            }
            return WeddingDetails(
                coupleNames: coupleNames,
                date: date,
                location: location,
                mealOptions: mealOptions,
                customQuestions: customQuestions
            )
        } catch let error as CKError where error.code == .unknownItem {
            let predicate = NSPredicate(format: "weddingId == %@", weddingId.uuidString)
            let query = CKQuery(recordType: "Wedding", predicate: predicate)
            let (matchResults, _) = try await privateDatabase.records(matching: query)
            
            for (_, result) in matchResults {
                switch result {
                case .success(let record):
                    let coupleNames = record["coupleNames"] as? String ?? ""
                    let date = record["date"] as? Date ?? Date()
                    let location = record["location"] as? String ?? ""
                    let mealOptions = record["mealOptions"] as? [String]
                    let customQuestions: [RSVPQuestion]?
                    if let questionsData = record["customQuestions"] as? Data {
                        customQuestions = try? JSONDecoder().decode([RSVPQuestion].self, from: questionsData)
                    } else if let legacyQuestions = record["customQuestions"] as? [String] {
                        customQuestions = legacyQuestions.enumerated().map { index, title in
                            RSVPQuestion(title: title, type: .text, displayOrder: index)
                        }
                    } else {
                        customQuestions = nil
                    }
                    return WeddingDetails(
                        coupleNames: coupleNames,
                        date: date,
                        location: location,
                        mealOptions: mealOptions,
                        customQuestions: customQuestions
                    )
                case .failure:
                    continue
                }
            }
            return nil
        } catch {
            throw error
        }
    }
    
    // MARK: - Guest Data
    
    func saveGuests(_ guests: [Guest], weddingId: UUID) async throws {
        for guest in guests {
            let recordID = guestRecordID(for: guest.id)
            let record = try await fetchOrCreateRecord(recordType: "Guest", recordID: recordID, in: privateDatabase)
            record["guestId"] = guest.id.uuidString
            record["name"] = guest.name
            record["email"] = guest.email
            record["phone"] = guest.phone
            record["side"] = guest.side.rawValue
            record["rsvpStatus"] = guest.rsvpStatus.rawValue
            record["mealChoice"] = guest.mealChoice
            record["dietaryNotes"] = guest.dietaryNotes
            record["household"] = guest.household
            record["partySize"] = guest.partySize as CKRecordValue
            record["invitationCode"] = guest.invitationCode
            if let checkedInAt = guest.checkedInAt {
                record["checkedInAt"] = checkedInAt as CKRecordValue
            } else {
                record["checkedInAt"] = nil
            }
            record["weddingId"] = weddingId.uuidString
            
            _ = try await privateDatabase.save(record)
        }
    }
    
    func fetchGuests(weddingId: UUID) async throws -> [Guest] {
        let predicate = NSPredicate(format: "weddingId == %@", weddingId.uuidString)
        let query = CKQuery(recordType: "Guest", predicate: predicate)
        let (matchResults, _) = try await privateDatabase.records(matching: query)
        
        var guestsById: [UUID: Guest] = [:]
        for (_, result) in matchResults {
            switch result {
            case .success(let record):
                guard let idString = record["guestId"] as? String,
                      let id = UUID(uuidString: idString),
                      let name = record["name"] as? String else { continue }
                
                let guest = Guest(
                    id: id,
                    name: name,
                    email: record["email"] as? String,
                    phone: record["phone"] as? String,
                    side: GuestSide(rawValue: record["side"] as? String ?? "Both") ?? .both,
                    rsvpStatus: RSVPStatus(rawValue: record["rsvpStatus"] as? String ?? "noResponse") ?? .noResponse,
                    mealChoice: record["mealChoice"] as? String,
                    dietaryNotes: record["dietaryNotes"] as? String,
                    household: record["household"] as? String,
                    partySize: record["partySize"] as? Int ?? 1,
                    invitationCode: record["invitationCode"] as? String,
                    checkedInAt: record["checkedInAt"] as? Date
                )
                guestsById[id] = guest
            case .failure:
                continue
            }
        }
        return Array(guestsById.values)
    }
    
    // MARK: - Budget Data
    
    func saveBudget(_ categories: [BudgetCategory], weddingId: UUID) async throws {
        for category in categories {
            let recordID = budgetRecordID(for: category.id)
            let record = try await fetchOrCreateRecord(recordType: "BudgetCategory", recordID: recordID, in: privateDatabase)
            record["categoryId"] = category.id.uuidString
            record["name"] = category.name
            record["allocated"] = category.allocated as CKRecordValue
            record["spent"] = category.spent as CKRecordValue
            record["weddingId"] = weddingId.uuidString
            
            _ = try await privateDatabase.save(record)
        }
    }
    
    func fetchBudget(weddingId: UUID) async throws -> [BudgetCategory] {
        let predicate = NSPredicate(format: "weddingId == %@", weddingId.uuidString)
        let query = CKQuery(recordType: "BudgetCategory", predicate: predicate)
        let (matchResults, _) = try await privateDatabase.records(matching: query)
        
        var categoriesById: [UUID: BudgetCategory] = [:]
        for (_, result) in matchResults {
            switch result {
            case .success(let record):
                guard let idString = record["categoryId"] as? String,
                      let id = UUID(uuidString: idString),
                      let name = record["name"] as? String,
                      let allocated = record["allocated"] as? Double,
                      let spent = record["spent"] as? Double else { continue }
                
                let category = BudgetCategory(
                    id: id,
                    name: name,
                    allocated: allocated,
                    spent: spent
                )
                categoriesById[id] = category
            case .failure:
                continue
            }
        }
        return Array(categoriesById.values)
    }
    
    // MARK: - Vendor Data
    
    func saveVendors(_ vendors: [Vendor], weddingId: UUID) async throws {
        for vendor in vendors {
            let recordID = vendorRecordID(for: vendor.id)
            let record = try await fetchOrCreateRecord(recordType: "Vendor", recordID: recordID, in: privateDatabase)
            record["vendorId"] = vendor.id.uuidString
            record["name"] = vendor.name
            record["category"] = vendor.category
            record["phone"] = vendor.phone
            record["email"] = vendor.email
            record["website"] = vendor.website
            record["notes"] = vendor.notes
            record["weddingId"] = weddingId.uuidString
            
            _ = try await privateDatabase.save(record)
        }
    }
    
    func fetchVendors(weddingId: UUID) async throws -> [Vendor] {
        let predicate = NSPredicate(format: "weddingId == %@", weddingId.uuidString)
        let query = CKQuery(recordType: "Vendor", predicate: predicate)
        let (matchResults, _) = try await privateDatabase.records(matching: query)
        
        var vendorsById: [UUID: Vendor] = [:]
        for (_, result) in matchResults {
            switch result {
            case .success(let record):
                guard let idString = record["vendorId"] as? String,
                      let id = UUID(uuidString: idString),
                      let name = record["name"] as? String,
                      let category = record["category"] as? String else { continue }
                
                let vendor = Vendor(
                    id: id,
                    name: name,
                    category: category,
                    phone: record["phone"] as? String,
                    email: record["email"] as? String,
                    website: record["website"] as? String,
                    notes: record["notes"] as? String
                )
                vendorsById[id] = vendor
            case .failure:
                continue
            }
        }
        return Array(vendorsById.values)
    }
    
    // MARK: - Guest RSVP (Public Database for Guest Submissions)
    
    func saveGuestRSVP(_ rsvp: GuestRSVP) async throws {
        try await upsertGuestRSVP(rsvp)
    }
    
    func fetchGuestRSVPs(for invitationCode: String) async throws -> [GuestRSVP] {
        let cleanCode = InvitationCode.normalize(invitationCode)
        let predicate = NSPredicate(format: "invitationCode == %@", cleanCode)
        let query = CKQuery(recordType: "GuestRSVP", predicate: predicate)
        let (matchResults, _) = try await publicDatabase.records(matching: query)
        
        var rsvps: [GuestRSVP] = []
        for (_, result) in matchResults {
            switch result {
            case .success(let record):
                guard let invitationCode = record["invitationCode"] as? String,
                      let guestName = record["guestName"] as? String,
                      let rsvpStatusString = record["rsvpStatus"] as? String,
                      let rsvpStatus = RSVPStatus(rawValue: rsvpStatusString) else { continue }
                
                let rsvp = GuestRSVP(
                    invitationCode: invitationCode,
                    guestName: guestName,
                    rsvpStatus: rsvpStatus,
                    mealChoice: record["mealChoice"] as? String,
                    dietaryNotes: record["dietaryNotes"] as? String,
                    partySize: record["partySize"] as? Int ?? 1,
                    songRequest: record["songRequest"] as? String
                )
                rsvps.append(rsvp)
            case .failure:
                continue
            }
        }
        return rsvps
    }
    
    /// Upsert guest RSVP - updates existing record or creates new one
    func upsertGuestRSVP(_ rsvp: GuestRSVP) async throws {
        let recordID = guestRSVPRecordID(for: rsvp)
        let record = try await fetchOrCreateRecord(recordType: "GuestRSVP", recordID: recordID, in: publicDatabase)
        record["invitationCode"] = InvitationCode.normalize(rsvp.invitationCode)
        record["guestName"] = rsvp.guestName
        record["rsvpStatus"] = rsvp.rsvpStatus.rawValue
        record["mealChoice"] = rsvp.mealChoice
        record["dietaryNotes"] = rsvp.dietaryNotes
        record["partySize"] = rsvp.partySize as CKRecordValue
        record["songRequest"] = rsvp.songRequest
        record["submittedAt"] = rsvp.submittedAt as CKRecordValue
        
        _ = try await publicDatabase.save(record)
    }
    
    // MARK: - Invitation Codes
    
    func saveInvitationCode(_ invitation: InvitationCode) async throws {
        let normalizedCode = InvitationCode.normalize(invitation.code)
        let recordID = invitationCodeRecordID(for: normalizedCode)
        let record = try await fetchOrCreateRecord(recordType: "InvitationCode", recordID: recordID, in: publicDatabase)
        record["code"] = normalizedCode
        record["weddingId"] = invitation.weddingId.uuidString
        record["coupleNames"] = invitation.coupleNames
        record["weddingDate"] = invitation.weddingDate as CKRecordValue
        record["weddingLocation"] = invitation.weddingLocation
        record["createdAt"] = invitation.createdAt as CKRecordValue
        record["guestId"] = invitation.guestId?.uuidString
        record["guestName"] = invitation.guestName
        record["rsvpStatus"] = invitation.rsvpStatus?.rawValue
        record["mealChoice"] = invitation.mealChoice
        record["dietaryNotes"] = invitation.dietaryNotes
        record["partySize"] = invitation.partySize as CKRecordValue
        record["phoneNumber"] = invitation.phoneNumber
        
        _ = try await publicDatabase.save(record)
    }
    
    func fetchInvitationCode(_ code: String) async throws -> InvitationCode? {
        do {
            let record = try await publicDatabase.record(for: invitationCodeRecordID(for: code))
            return makeInvitationCode(from: record)
        } catch let error as CKError where error.code == .unknownItem {
            let normalizedCode = InvitationCode.normalize(code)
            let predicate = NSPredicate(format: "code == %@", normalizedCode)
            let query = CKQuery(recordType: "InvitationCode", predicate: predicate)
            let (matchResults, _) = try await publicDatabase.records(matching: query)
            
            for (_, result) in matchResults {
                switch result {
                case .success(let record):
                    return makeInvitationCode(from: record)
                case .failure:
                    continue
                }
            }
            return nil
        } catch {
            throw error
        }
    }

    func fetchInvitationCodes(weddingId: UUID) async throws -> [InvitationCode] {
        let predicate = NSPredicate(format: "weddingId == %@", weddingId.uuidString)
        let query = CKQuery(recordType: "InvitationCode", predicate: predicate)
        let (matchResults, _) = try await publicDatabase.records(matching: query)

        var invitations: [InvitationCode] = []
        for (_, result) in matchResults {
            switch result {
            case .success(let record):
                if let invitation = makeInvitationCode(from: record) {
                    invitations.append(invitation)
                }
            case .failure:
                continue
            }
        }

        return invitations.sorted { $0.createdAt < $1.createdAt }
    }
    
    private func makeInvitationCode(from record: CKRecord) -> InvitationCode? {
        guard let code = record["code"] as? String,
              let weddingIdString = record["weddingId"] as? String,
              let weddingId = UUID(uuidString: weddingIdString),
              let coupleNames = record["coupleNames"] as? String,
              let weddingDate = record["weddingDate"] as? Date,
              let weddingLocation = record["weddingLocation"] as? String else {
            return nil
        }
        
        var invitation = InvitationCode(
            code: code,
            weddingId: weddingId,
            coupleNames: coupleNames,
            date: weddingDate,
            location: weddingLocation,
            createdAt: record["createdAt"] as? Date ?? Date(),
            guestId: {
                guard let guestIdString = record["guestId"] as? String else { return nil }
                return UUID(uuidString: guestIdString)
            }(),
            guestName: record["guestName"] as? String,
            partySize: record["partySize"] as? Int ?? 1,
            phoneNumber: record["phoneNumber"] as? String
        )
        if let statusRawValue = record["rsvpStatus"] as? String {
            invitation.rsvpStatus = RSVPStatus(rawValue: statusRawValue)
        }
        invitation.mealChoice = record["mealChoice"] as? String
        invitation.dietaryNotes = record["dietaryNotes"] as? String
        return invitation
    }
    
    // MARK: - Event Photos
    
    func saveEventPhoto(
        photoId: UUID = UUID(),
        imageURL: URL,
        weddingId: UUID,
        invitationCode: String,
        guestName: String,
        caption: String?
    ) async throws -> EventPhoto {
        let recordID = eventPhotoRecordID(for: photoId)
        let record = try await fetchOrCreateRecord(recordType: "EventPhoto", recordID: recordID, in: publicDatabase)
        record["photoId"] = photoId.uuidString
        record["weddingId"] = weddingId.uuidString
        record["invitationCode"] = invitationCode
        record["guestName"] = guestName
        record["caption"] = caption
        record["uploadedAt"] = Date() as CKRecordValue
        record["image"] = CKAsset(fileURL: imageURL)
        
        let savedRecord = try await publicDatabase.save(record)
        return EventPhoto(
            id: photoId,
            weddingId: weddingId,
            invitationCode: invitationCode,
            guestName: guestName,
            caption: caption,
            uploadedAt: savedRecord["uploadedAt"] as? Date ?? Date(),
            imageURL: (savedRecord["image"] as? CKAsset)?.fileURL
        )
    }
    
    func fetchEventPhotos(weddingId: UUID) async throws -> [EventPhoto] {
        let predicate = NSPredicate(format: "weddingId == %@", weddingId.uuidString)
        let query = CKQuery(recordType: "EventPhoto", predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: "uploadedAt", ascending: false)]
        let (matchResults, _) = try await publicDatabase.records(matching: query)
        
        var photos: [EventPhoto] = []
        for (_, result) in matchResults {
            switch result {
            case .success(let record):
                guard let photoIdString = record["photoId"] as? String,
                      let photoId = UUID(uuidString: photoIdString),
                      let weddingIdString = record["weddingId"] as? String,
                      let parsedWeddingId = UUID(uuidString: weddingIdString),
                      let invitationCode = record["invitationCode"] as? String,
                      let guestName = record["guestName"] as? String else {
                    continue
                }
                let photo = EventPhoto(
                    id: photoId,
                    weddingId: parsedWeddingId,
                    invitationCode: invitationCode,
                    guestName: guestName,
                    caption: record["caption"] as? String,
                    uploadedAt: record["uploadedAt"] as? Date ?? Date(),
                    imageURL: (record["image"] as? CKAsset)?.fileURL
                )
                photos.append(photo)
            case .failure:
                continue
            }
        }
        return photos
    }
    
    // MARK: - Co-Planner Management
    
    func generateCoPlannerCode(weddingId: UUID) async throws -> String {
        let code = InvitationCode.makeCode()
        
        let record = CKRecord(recordType: "CoPlanner", recordID: coPlannerRecordID(for: code))
        record["code"] = code
        record["weddingId"] = weddingId.uuidString
        record["createdAt"] = Date() as CKRecordValue
        
        _ = try await publicDatabase.save(record)
        return code
    }
    
    func validateCoPlannerCode(_ code: String) async throws -> String? {
        do {
            let record = try await publicDatabase.record(for: coPlannerRecordID(for: code))
            return record["weddingId"] as? String
        } catch let error as CKError where error.code == .unknownItem {
            let normalizedCode = InvitationCode.normalize(code)
            let predicate = NSPredicate(format: "code == %@", normalizedCode)
            let query = CKQuery(recordType: "CoPlanner", predicate: predicate)
            let (matchResults, _) = try await publicDatabase.records(matching: query)
            
            for (_, result) in matchResults {
                switch result {
                case .success(let record):
                    return record["weddingId"] as? String
                case .failure:
                    continue
                }
            }
            return nil
        } catch {
            throw error
        }
    }
    
    struct SchemaTestResult {
        let status: String
        let invitationCode: String
    }

    @discardableResult
    func runSchemaPreparationTest(weddingId: UUID) async throws -> SchemaTestResult {
        let details = WeddingDetails(
            coupleNames: "Schema Test Wedding",
            date: Date(),
            location: "CloudKit Test Venue"
        )
        _ = try await saveWedding(details, weddingId: weddingId)

        let invitation = InvitationCode(
            code: InvitationCode.makeCode(),
            weddingId: weddingId,
            coupleNames: details.coupleNames,
            date: details.date,
            location: details.location,
            guestName: "Schema Test Guest",
            partySize: 2,
            phoneNumber: "555-0000"
        )
        try await saveInvitationCode(invitation)

        let guest = Guest(
            name: invitation.guestName ?? "Schema Test Guest",
            email: "schema@test.com",
            phone: invitation.phoneNumber,
            side: .both,
            rsvpStatus: .attending,
            mealChoice: "Chicken",
            dietaryNotes: "None",
            partySize: invitation.partySize,
            invitationCode: invitation.code
        )
        try await saveGuests([guest], weddingId: weddingId)

        let rsvp = GuestRSVP(
            invitationCode: invitation.code,
            guestName: guest.name,
            rsvpStatus: .attending,
            mealChoice: guest.mealChoice,
            dietaryNotes: guest.dietaryNotes,
            partySize: guest.partySize
        )
        try await upsertGuestRSVP(rsvp)

        _ = try await fetchInvitationCode(invitation.code)
        _ = try await fetchGuestRSVPs(for: invitation.code)

        return SchemaTestResult(status: "Schema test completed", invitationCode: invitation.code)
    }

    // MARK: - Full Sync
    
    func syncAllData(weddingId: UUID) async throws -> (
        wedding: WeddingDetails?,
        guests: [Guest],
        budget: [BudgetCategory],
        vendors: [Vendor]
    ) {
        async let weddingTask = fetchWedding(weddingId: weddingId)
        async let guestsTask = fetchGuests(weddingId: weddingId)
        async let budgetTask = fetchBudget(weddingId: weddingId)
        async let vendorsTask = fetchVendors(weddingId: weddingId)
        
        let (wedding, guests, budget, vendors) = try await (weddingTask, guestsTask, budgetTask, vendorsTask)
        return (wedding, guests, budget, vendors)
    }
    
    // MARK: - Real-Time Sync (For co-planner collaboration)
    
    /// Subscribe to changes in private database
    func subscribeToPrivateChanges() async throws {
        let subscription = CKDatabaseSubscription(subscriptionID: "all-private-changes")
        _ = try await privateDatabase.save(subscription)
    }
    
    /// Subscribe to guest RSVP changes (public database)
    func subscribeToRSVPChanges() async throws {
        let subscription = CKDatabaseSubscription(subscriptionID: "all-rsvp-changes")
        _ = try await publicDatabase.save(subscription)
    }
    
    /// Create query subscription for specific wedding
    func subscribeToWeddingChanges(weddingId: UUID) async throws {
        let predicate = NSPredicate(format: "weddingId == %@", weddingId.uuidString)
        let subscription = CKQuerySubscription(
            recordType: "Guest",
            predicate: predicate,
            subscriptionID: "wedding-\(weddingId.uuidString)-changes",
            options: .firesOnRecordUpdate
        )
        _ = try await privateDatabase.save(subscription)
    }
    
    // MARK: - Change Notification Handler
    func handleRemoteChange(_ notification: CKDatabaseNotification) async {
        print("☁️ CloudKit remote change detected")
        // Note: This will be called from AppState when handling notifications
    }
}
