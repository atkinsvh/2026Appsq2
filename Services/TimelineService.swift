import Foundation

class TimelineService {
    static let shared = TimelineService()
    
    private init() {}
    
    func generateTimeline(weddingDate: Date, planningStage: String) -> [TimelineItem] {
        // Generate 12-month roadmap
        var items: [TimelineItem] = []
        let calendar = Calendar.current
        for i in 0..<12 {
            if let dueDate = calendar.date(byAdding: .month, value: -(12 - i), to: weddingDate) {
                let title: String
                switch i {
                case 0: title = "Book Venue"
                case 1: title = "Hire Photographer"
                case 2: title = "Send Invitations"
                case 3: title = "Choose Cake"
                case 4: title = "Buy Dress"
                case 5: title = "Plan Honeymoon"
                case 6: title = "Select Music"
                case 7: title = "Arrange Transportation"
                case 8: title = "Finalize Menu"
                case 9: title = "Book Officiant"
                case 10: title = "Send Thank Yous"
                case 11: title = "Wedding Day"
                default: title = "Milestone \(i+1)"
                }
                items.append(TimelineItem(title: title, dueDate: dueDate, completed: false))
            }
        }
        return items
    }
}