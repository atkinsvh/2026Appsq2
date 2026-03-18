import Foundation

// MARK: - Guest Models

enum RSVPStatus: String, Codable, CaseIterable {
    case attending, declined, noResponse
}

enum GuestSide: String, Codable, CaseIterable {
    case partnerOne = "Partner One"
    case partnerTwo = "Partner Two"
    case both = "Both"
}

enum GuestError: Error {
    case invalidName
    case invalidSide
    case invalidGroupTag
}

enum GuestGroupTag: String, Codable {
    case family = "Family"
    case friends = "Friends"
    case work = "Work"
    case other = "Other"
}

struct Guest: Identifiable, Hashable, Codable {
    let id: UUID
    var name: String
    var email: String?
    var phone: String?
    var side: GuestSide
    var rsvpStatus: RSVPStatus
    var mealChoice: String?
    var dietaryNotes: String?
    var household: String?
    var partySize: Int
    var invitationCode: String?
    var checkedInAt: Date?

    var isCheckedIn: Bool {
        checkedInAt != nil
    }
    
    init(id: UUID = UUID(),
         name: String,
         email: String? = nil,
         phone: String? = nil,
         side: GuestSide = .both,
         rsvpStatus: RSVPStatus = .noResponse,
         mealChoice: String? = nil,
         dietaryNotes: String? = nil,
         household: String? = nil,
         partySize: Int = 1,
         invitationCode: String? = nil,
         checkedInAt: Date? = nil) {
        self.id = id
        self.name = name
        self.email = email
        self.phone = phone
        self.side = side
        self.rsvpStatus = rsvpStatus
        self.mealChoice = mealChoice
        self.dietaryNotes = dietaryNotes
        self.household = household
        self.partySize = partySize
        self.invitationCode = invitationCode
        self.checkedInAt = checkedInAt
    }
}

// MARK: - Vendor Models

struct Vendor: Identifiable, Hashable, Codable {
    let id: UUID
    var name: String
    var category: String
    var phone: String?
    var email: String?
    var website: String?
    var notes: String?
    
    init(id: UUID = UUID(),
         name: String,
         category: String,
         phone: String? = nil,
         email: String? = nil,
         website: String? = nil,
         notes: String? = nil) {
        self.id = id
        self.name = name
        self.category = category
        self.phone = phone
        self.email = email
        self.website = website
        self.notes = notes
    }
}

// MARK: - Budget Models

struct BudgetCategory: Identifiable, Hashable, Codable {
    let id: UUID
    var name: String
    var allocated: Double
    var spent: Double
    
    var remaining: Double { max(allocated - spent, 0) }
    var progress: Double {
        guard allocated > 0 else { return 0 }
        return min(spent / allocated, 1.0)
    }
    
    init(id: UUID = UUID(),
         name: String,
         allocated: Double,
         spent: Double = 0) {
        self.id = id
        self.name = name
        self.allocated = allocated
        self.spent = spent
    }
}

struct BudgetEntry: Identifiable, Hashable, Codable {
    let id: UUID
    var categoryId: UUID
    var amount: Double
    var note: String
    var date: Date
    
    init(id: UUID = UUID(),
         categoryId: UUID,
         amount: Double,
         note: String,
         date: Date = Date()) {
        self.id = id
        self.categoryId = categoryId
        self.amount = amount
        self.note = note
        self.date = date
    }
}

// MARK: - Timeline Models

struct TimelineItem: Identifiable, Hashable, Codable {
    let id: UUID
    var title: String
    var dueDate: Date
    var completed: Bool
    
    init(id: UUID = UUID(),
         title: String,
         dueDate: Date,
         completed: Bool = false) {
        self.id = id
        self.title = title
        self.dueDate = dueDate
        self.completed = completed
    }
}

// MARK: - Wedding Models

struct WeddingDetails: Codable {
    var coupleNames: String
    var date: Date
    var location: String
    var mealOptions: [String]
    var customQuestions: [String]
    
    static var defaultMealOptions: [String] {
        ["Chicken", "Beef", "Fish", "Vegetarian", "Vegan", "Other"]
    }
    
    static var defaultCustomQuestions: [String] {
        []
    }
    
    init(coupleNames: String = "", date: Date = Date(), location: String = "", mealOptions: [String]? = nil, customQuestions: [String]? = nil) {
        self.coupleNames = coupleNames
        self.date = date
        self.location = location
        self.mealOptions = mealOptions ?? WeddingDetails.defaultMealOptions
        self.customQuestions = customQuestions ?? []
    }
}

// MARK: - General Models

struct GuestStats {
    let total: Int
    let attending: Int
    let pending: Int
    let totalPartySize: Int
    let attendingPartySize: Int
}

struct BudgetSummary {
    let planned: Double
    let spent: Double
}

// MARK: - Invitation System

struct InvitationCode: Identifiable, Codable {
    let id: UUID
    let code: String
    let weddingId: UUID
    let coupleNames: String
    let weddingDate: Date
    let weddingLocation: String
    let createdAt: Date
    var guestId: UUID?
    var guestName: String?
    var rsvpStatus: RSVPStatus?
    var mealChoice: String?
    var dietaryNotes: String?
    var partySize: Int
    var phoneNumber: String?
    
    static func makeCode() -> String {
        String((0..<6).map { _ in "ABCDEFGHJKLMNPQRSTUVWXYZ23456789".randomElement()! })
    }
    
    init(code: String? = nil,
         weddingId: UUID,
         coupleNames: String,
         date: Date,
         location: String,
         createdAt: Date = Date(),
         guestId: UUID? = nil,
         guestName: String? = nil,
         partySize: Int = 1,
         phoneNumber: String? = nil) {
        self.id = UUID()
        self.code = code ?? InvitationCode.makeCode()
        self.weddingId = weddingId
        self.coupleNames = coupleNames
        self.weddingDate = date
        self.weddingLocation = location
        self.createdAt = createdAt
        self.guestId = guestId
        self.guestName = guestName
        self.rsvpStatus = nil
        self.mealChoice = nil
        self.dietaryNotes = nil
        self.partySize = partySize
        self.phoneNumber = phoneNumber
    }
}

struct GuestRSVP: Codable {
    var invitationCode: String
    var guestName: String
    var rsvpStatus: RSVPStatus
    var mealChoice: String?
    var dietaryNotes: String?
    var partySize: Int
    var submittedAt: Date
    
    init(invitationCode: String, guestName: String, rsvpStatus: RSVPStatus, mealChoice: String? = nil, dietaryNotes: String? = nil, partySize: Int = 1) {
        self.invitationCode = invitationCode
        self.guestName = guestName
        self.rsvpStatus = rsvpStatus
        self.mealChoice = mealChoice
        self.dietaryNotes = dietaryNotes
        self.partySize = partySize
        self.submittedAt = Date()
    }
}

struct EventPhoto: Identifiable, Hashable {
    let id: UUID
    let weddingId: UUID
    let invitationCode: String
    let guestName: String
    let caption: String?
    let uploadedAt: Date
    let imageURL: URL?
}
import Foundation

extension Array where Element == Guest {
    func generateCSV() -> String {
        var csvString = "Name,Email,Phone,Invitation Code,Side,RSVP Status,Checked In,Checked In At,Party Size,Meal Choice,Dietary Notes,Household\n"
        
        for guest in self {
            let name = guest.name.replacingOccurrences(of: ",", with: " ")
            let email = guest.email?.replacingOccurrences(of: ",", with: " ") ?? ""
            let phone = guest.phone?.replacingOccurrences(of: ",", with: " ") ?? ""
            let invitationCode = guest.invitationCode?.replacingOccurrences(of: ",", with: " ") ?? ""
            let side = guest.side.rawValue
            let rsvp = guest.rsvpStatus.rawValue
            let checkedIn = guest.isCheckedIn ? "Yes" : "No"
            let checkedInAt = guest.checkedInAt.map { ISO8601DateFormatter().string(from: $0) } ?? ""
            let partySize = "\(guest.partySize)"
            let meal = guest.mealChoice?.replacingOccurrences(of: ",", with: " ") ?? ""
            let dietary = guest.dietaryNotes?.replacingOccurrences(of: ",", with: " ") ?? ""
            let household = guest.household?.replacingOccurrences(of: ",", with: " ") ?? ""
            
            let row = "\(name),\(email),\(phone),\(invitationCode),\(side),\(rsvp),\(checkedIn),\(checkedInAt),\(partySize),\(meal),\(dietary),\(household)\n"
            csvString.append(row)
        }
        
        return csvString
    }
}
