import Foundation

class OnboardingService {
    static let shared = OnboardingService()
    
    private init() {}
    
    func addGuest(name: String, email: String?) {
        // Implementation for adding guest during onboarding
        print("Added guest: \(name)")
    }
    
    func setupWebsite(template: String) {
        // Implementation for website setup
        print("Website setup with template: \(template)")
    }
}