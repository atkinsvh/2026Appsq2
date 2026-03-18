import Foundation

actor WeddingPageStoreActor {
    private let fileManager = FileManager.default
    private let documentsURL: URL
    
    init() {
        documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    func saveWeddingPageHTML(_ html: String) async throws {
        let data = Data(html.utf8)
        let weddingPageDir = documentsURL.appendingPathComponent("WeddingPagePreview")
        try fileManager.createDirectory(at: weddingPageDir, withIntermediateDirectories: true)
        try data.write(to: weddingPageDir.appendingPathComponent("index.html"))
    }
    
    func getWeddingPageURL() -> URL? {
        let weddingPageDir = documentsURL.appendingPathComponent("WeddingPagePreview")
        return weddingPageDir.appendingPathComponent("index.html")
    }
}