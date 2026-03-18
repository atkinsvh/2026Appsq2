import Foundation

actor GuestStoreActor {
    private let fileManager = FileManager.default
    private let documentsURL: URL
    
    init() {
        documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    func saveGuests(_ guests: [Guest]) async throws {
        let data = try JSONEncoder().encode(guests)
        try data.write(to: documentsURL.appendingPathComponent("guests.json"))
    }
    
    func loadGuests() async -> [Guest] {
        let url = documentsURL.appendingPathComponent("guests.json")
        guard let data = try? Data(contentsOf: url) else { return [] }
        return (try? JSONDecoder().decode([Guest].self, from: data)) ?? []
    }
    
    func getGuestStats(_ guests: [Guest]) -> GuestStats {
        let total = guests.count
        let attending = guests.filter { $0.rsvpStatus == .attending }.count
        let pending = guests.filter { $0.rsvpStatus == .noResponse }.count
        let totalPartySize = guests.reduce(0) { $0 + $1.partySize }
        let attendingPartySize = guests.filter { $0.rsvpStatus == .attending }.reduce(0) { $0 + $1.partySize }
        return GuestStats(
            total: total,
            attending: attending,
            pending: pending,
            totalPartySize: totalPartySize,
            attendingPartySize: attendingPartySize
        )
    }
}