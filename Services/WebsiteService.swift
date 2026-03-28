import Foundation
import OSLog

struct WebsiteGenerationRequest {
    let coupleNames: String
    let date: String
    let location: String
    let attendingGuests: [Guest]
    let template: WebsiteTemplate
}

struct GeneratedWebsite {
    let html: String
    let fileURL: URL
}

enum WebsiteServiceError: LocalizedError {
    case unableToLocateDocumentsDirectory
    case htmlEncodingFailed
    case failedToWriteFile(underlyingError: Error)

    var errorDescription: String? {
        switch self {
        case .unableToLocateDocumentsDirectory:
            return "Could not find a writable documents directory for website output."
        case .htmlEncodingFailed:
            return "Website generation failed because HTML output could not be encoded."
        case .failedToWriteFile(let underlyingError):
            return "Unable to save website output: \(underlyingError.localizedDescription)"
        }
    }
}

class WebsiteService {
    static let shared = WebsiteService()

    private let logger: Logger
    private let fileManager: FileManager
    private let documentsDirectoryProvider: () -> URL?

    private init(
        fileManager: FileManager = .default,
        logger: Logger = Logger(subsystem: "com.vowplanner.app", category: "WebsiteService"),
        documentsDirectoryProvider: @escaping () -> URL? = {
            FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        }
    ) {
        self.fileManager = fileManager
        self.logger = logger
        self.documentsDirectoryProvider = documentsDirectoryProvider
    }

    static func testing(
        fileManager: FileManager = .default,
        documentsDirectoryProvider: @escaping () -> URL?
    ) -> WebsiteService {
        WebsiteService(
            fileManager: fileManager,
            logger: Logger(subsystem: "com.vowplanner.app.tests", category: "WebsiteService"),
            documentsDirectoryProvider: documentsDirectoryProvider
        )
    }

    func generateWebsite(
        request: WebsiteGenerationRequest,
        fileName: String = "wedding_website.html"
    ) -> Result<GeneratedWebsite, WebsiteServiceError> {
        let html = WebsiteGenerator.shared.generateHTML(
            coupleNames: request.coupleNames,
            date: request.date,
            location: request.location,
            attendingGuests: request.attendingGuests,
            template: request.template
        )

        guard let htmlData = html.data(using: .utf8) else {
            logger.error("Website HTML encoding failed")
            return .failure(.htmlEncodingFailed)
        }

        guard let documentsDirectory = documentsDirectoryProvider() else {
            logger.error("Documents directory unavailable")
            return .failure(.unableToLocateDocumentsDirectory)
        }

        let outputURL = documentsDirectory.appendingPathComponent(fileName)

        do {
            if !fileManager.fileExists(atPath: documentsDirectory.path) {
                try fileManager.createDirectory(at: documentsDirectory, withIntermediateDirectories: true)
            }
            try htmlData.write(to: outputURL, options: .atomic)
            logger.info("Generated website at \(outputURL.path, privacy: .public)")
            return .success(GeneratedWebsite(html: html, fileURL: outputURL))
        } catch {
            logger.error("Website write failed: \(error.localizedDescription, privacy: .public)")
            return .failure(.failedToWriteFile(underlyingError: error))
        }
    }
}
