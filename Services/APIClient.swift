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

    /// Fetch all weddings a user can access (host and/or co-planner).
    /// This mock implementation reads memberships from local storage.
    func fetchWeddings(for userId: UUID) async -> [WeddingSummary] {
        let fileName = "user_wedding_memberships_\(userId.uuidString.lowercased()).json"
        let memberships = DataStore.shared.load([UserWeddingMembership].self, from: fileName) ?? []
        return memberships
            .sorted(by: { $0.weddingDate < $1.weddingDate })
            .map(WeddingSummary.init(membership:))
    }

    func fetchWeddings(for userId: UUID, completion: @escaping ([WeddingSummary]) -> Void) {
        Task {
            completion(await fetchWeddings(for: userId))
        }
    }
}
