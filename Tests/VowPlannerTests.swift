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

}
