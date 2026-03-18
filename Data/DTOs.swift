import Foundation

struct GuestDTO: Codable {
    let id: UUID
    let name: String
    let rsvpStatus: String
}

struct BudgetDTO: Codable {
    let id: UUID
    let name: String
    let allocated: Double
    let spent: Double
}