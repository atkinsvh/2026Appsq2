import Foundation

class WebsiteService {
    static let shared = WebsiteService()
    
    private init() {}
    
    func generateWebsite(data: [String: Any]) {
        // Communicate with WebsiteGenerator
        let html = WebsiteGenerator.shared.generateHTML(from: data)
        // TODO: Save or display the generated HTML
        print("Generated website HTML: \(html)")
    }
}