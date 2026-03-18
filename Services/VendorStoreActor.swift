import Foundation

actor VendorStoreActor {
    private let fileManager = FileManager.default
    private let documentsURL: URL
    
    init() {
        documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    func saveVendors(_ vendors: [Vendor]) async throws {
        let data = try JSONEncoder().encode(vendors)
        try data.write(to: documentsURL.appendingPathComponent("vendors.json"))
    }
    
    func loadVendors() async -> [Vendor] {
        let url = documentsURL.appendingPathComponent("vendors.json")
        guard let data = try? Data(contentsOf: url) else { return [] }
        return (try? JSONDecoder().decode([Vendor].self, from: data)) ?? []
    }
}