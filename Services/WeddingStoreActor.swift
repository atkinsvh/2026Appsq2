import Foundation

// Assuming WeddingDetails is in Shared/Models/WeddingDetails.swift

actor WeddingStoreActor {
    private let fileManager = FileManager.default
    private let documentsURL: URL
    
    init() {
        documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    func saveWeddingDetails(_ details: WeddingDetails) async throws {
        let data = try JSONEncoder().encode(details)
        try data.write(to: documentsURL.appendingPathComponent("wedding.json"))
    }
    
    func loadWeddingDetails() async -> WeddingDetails? {
        let url = documentsURL.appendingPathComponent("wedding.json")
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(WeddingDetails.self, from: data)
    }
}