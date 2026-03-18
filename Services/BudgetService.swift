import Foundation

actor BudgetService {
    private let fileManager = FileManager.default
    private let documentsURL: URL
    
    init() {
        documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    func saveBudgetCategories(_ categories: [BudgetCategory]) async throws {
        let data = try JSONEncoder().encode(categories)
        try data.write(to: documentsURL.appendingPathComponent("budget_categories.json"))
    }
    
    func loadBudgetCategories() async -> [BudgetCategory] {
        let primaryURL = documentsURL.appendingPathComponent("budget_categories.json")
        let legacyURL = documentsURL.appendingPathComponent("budget.json")
        let url = fileManager.fileExists(atPath: primaryURL.path) ? primaryURL : legacyURL
        guard let data = try? Data(contentsOf: url) else { return [] }
        return (try? JSONDecoder().decode([BudgetCategory].self, from: data)) ?? []
    }
    
    func saveBudgetEntries(_ entries: [BudgetEntry]) async throws {
        let data = try JSONEncoder().encode(entries)
        try data.write(to: documentsURL.appendingPathComponent("budget_entries.json"))
    }
    
    func loadBudgetEntries() async -> [BudgetEntry] {
        let url = documentsURL.appendingPathComponent("budget_entries.json")
        guard let data = try? Data(contentsOf: url) else { return [] }
        return (try? JSONDecoder().decode([BudgetEntry].self, from: data)) ?? []
    }
    
    func getBudgetSummary(categories: [BudgetCategory], entries: [BudgetEntry]) -> (planned: Double, spent: Double) {
        let planned = categories.reduce(0) { $0 + $1.allocated }
        let spent = entries.reduce(0) { $0 + $1.amount }
        return (planned: planned, spent: spent)
    }

    func setupBudget(lines: [BudgetCategory]) {
        // Setup budget
        print("Budget setup with \(lines.count) lines")
    }
    
    func trackSpending(category: BudgetCategory, amount: Double) {
        // Track spending
        print("Tracked $\(amount) in \(category.name)")
    }
}
