import Foundation

class WeddingService {
    static let shared = WeddingService()
    
    private init() {}
    
    func updateWeddingDetails(date: Date, location: String) {
        // Update details
        print("Wedding on \(date) at \(location)")
    }
    
    func getTimeline() -> [TimelineItem] {
        // Get timeline
        return []
    }
}