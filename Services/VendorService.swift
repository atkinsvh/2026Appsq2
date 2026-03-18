import Foundation

class VendorService {
    static let shared = VendorService()
    
    private init() {}
    
    func addVendor(_ vendor: Vendor) {
        // Add vendor
        print("Added vendor: \(vendor.name)")
    }
    
    func getVendors(by category: String) -> [Vendor] {
        // Get vendors by category
        return []
    }
}