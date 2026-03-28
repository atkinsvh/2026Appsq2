//
//  VowPlannerTests.swift
//  VowPlannerTests
//
//  Created by Victoria Entwistle on 12/9/25.
//

import XCTest
@testable import VowPlanner

final class VowPlannerTests: XCTestCase {

    func testBackupsToPruneKeepsNewestFiveForMatchingFileOnly() {
        let backups = [
            "2026-03-18T00-00-00Z-guests.json",
            "2026-03-18T01-00-00Z-guests.json",
            "2026-03-18T02-00-00Z-guests.json",
            "2026-03-18T03-00-00Z-guests.json",
            "2026-03-18T04-00-00Z-guests.json",
            "2026-03-18T05-00-00Z-guests.json",
            "2026-03-18T06-00-00Z-budget.json"
        ].map { URL(fileURLWithPath: "/tmp/\($0)") }

        let pruned = DataStore.backupsToPrune(backups, for: "guests.json")

        XCTAssertEqual(
            pruned.map(\.lastPathComponent),
            ["2026-03-18T00-00-00Z-guests.json"]
        )
    }

    func testBackupCandidatesAreOrderedNewestFirst() {
        let backups = [
            "2026-03-18T01-00-00Z-guests.json",
            "2026-03-18T03-00-00Z-guests.json",
            "2026-03-18T02-00-00Z-guests.json"
        ].map { URL(fileURLWithPath: "/tmp/\($0)") }

        let candidates = DataStore.backupCandidates(backups, for: "guests.json")

        XCTAssertEqual(
            candidates.map(\.lastPathComponent),
            [
                "2026-03-18T03-00-00Z-guests.json",
                "2026-03-18T02-00-00Z-guests.json",
                "2026-03-18T01-00-00Z-guests.json"
            ]
        )
    }

    func testInvitationCodeNormalizationRemovesWhitespaceAndSymbols() {
        XCTAssertEqual(InvitationCode.normalize(" ab-c 12!34 "), "ABC123")
    }

    func testGuestRSVPNormalizesInvitationCodeOnInit() {
        let rsvp = GuestRSVP(invitationCode: " test-9 ", guestName: "Guest", rsvpStatus: .attending)

        XCTAssertEqual(rsvp.invitationCode, "TEST9")
    }


    func testPartnerInviteShareTextIncludesCodeAndLinksWhenConfigured() {
        let text = PartnerInviteShareBuilder.makeShareText(
            websiteLink: "https://goodvibez.vowplanner.life",
            inviteCode: "ABC123",
            appStoreURL: "https://apps.apple.com/us/app/vow-planner/id123456789",
            inviteLink: "https://goodvibez.vowplanner.life/invite?code=ABC123"
        )

        XCTAssertTrue(text.contains("ABC123"))
        XCTAssertTrue(text.contains("https://goodvibez.vowplanner.life"))
        XCTAssertTrue(text.contains("https://apps.apple.com/us/app/vow-planner/id123456789"))
        XCTAssertTrue(text.contains("/invite?code=ABC123"))
    }

    func testPartnerInviteShareTextOmitsAppStoreSectionWhenLinkMissing() {
        let text = PartnerInviteShareBuilder.makeShareText(
            websiteLink: "https://goodvibez.vowplanner.life",
            inviteCode: "ZZTOP1",
            appStoreURL: nil,
            inviteLink: nil
        )

        XCTAssertFalse(text.contains("App Store"))
        XCTAssertTrue(text.contains("ZZTOP1"))
        XCTAssertTrue(text.contains("Website:"))
    }

    func testWebsiteServiceGenerateWebsiteSuccessWritesFileAndReturnsHTML() {
        let tempDirectory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("WebsiteServiceTests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDirectory) }

        let service = WebsiteService.testing(documentsDirectoryProvider: { tempDirectory })
        let request = WebsiteGenerationRequest(
            coupleNames: "Alex & Sam",
            date: "June 1, 2026",
            location: "Austin, TX",
            attendingGuests: [],
            template: .classic
        )

        let result = service.generateWebsite(request: request, fileName: "test_website.html")

        switch result {
        case .success(let generated):
            XCTAssertEqual(generated.fileURL.lastPathComponent, "test_website.html")
            XCTAssertTrue(FileManager.default.fileExists(atPath: generated.fileURL.path))
            XCTAssertTrue(generated.html.contains("Alex &amp; Sam") || generated.html.contains("Alex & Sam"))
        case .failure(let error):
            XCTFail("Expected success but got failure: \(error.localizedDescription)")
        }
    }

    func testWebsiteServiceGenerateWebsiteFailsWithoutDocumentsDirectory() {
        let service = WebsiteService.testing(documentsDirectoryProvider: { nil })
        let request = WebsiteGenerationRequest(
            coupleNames: "Alex & Sam",
            date: "June 1, 2026",
            location: "Austin, TX",
            attendingGuests: [],
            template: .classic
        )

        let result = service.generateWebsite(request: request)

        switch result {
        case .success:
            XCTFail("Expected failure when documents directory is unavailable")
        case .failure(let error):
            guard case .unableToLocateDocumentsDirectory = error else {
                return XCTFail("Unexpected error: \(error.localizedDescription)")
            }
        }
    }

}
