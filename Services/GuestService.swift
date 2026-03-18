import Foundation

class GuestService {
    static let shared = GuestService()
    
    private init() {}
    
    func addGuest(_ guest: Guest) {
        // Persist guest or send to API
        print("Added guest: \(guest.name)")
        // In a real app, save to database or API
    }
    
    func editGuest(_ guest: Guest) {
        // Update guest
        print("Edited guest: \(guest.name)")
        // In a real app, update in database or API
    }
    
    func getGuests() -> [Guest] {
        // Return guest list from persistence
        // For now, return empty as AppState manages the data
        return []
    }
}