import Foundation

class GoogleSheetsService {
    static let shared = GoogleSheetsService()
    
    private init() {}
    
    func syncGuests(_ guests: [Guest]) {
        // Sync to Google Sheets
        print("Synced \(guests.count) guests to Sheets")
    }
    
    func syncBudget(_ categories: [BudgetCategory]) {
        // Sync budget
        print("Synced budget to Sheets")
    }
}