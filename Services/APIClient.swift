import Foundation

class APIClient {
    static let shared = APIClient()
    
    private init() {}
    
    func fetchGuests(completion: @escaping ([Guest]) -> Void) {
        // Mock API call
        completion([])
    }
    
    func postRSVP(guest: Guest, status: RSVPStatus) {
        // Post to API
        print("Posted RSVP for \(guest.name)")
    }
}