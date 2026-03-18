import Foundation

class RSVPService {
    static let shared = RSVPService()
    
    private init() {}
    
    func trackRSVP(guest: Guest, status: RSVPStatus) {
        // Track RSVP
        print("RSVP for \(guest.name): \(status)")
    }
    
    func getRSVPStats() -> [String: Int] {
        // Return stats
        return ["attending": 0, "declined": 0, "noResponse": 0]
    }
}