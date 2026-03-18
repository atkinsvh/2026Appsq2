// CloudKit Test Script
// Run this in Simulator/Device to verify CloudKit is working

import CloudKit

let container = CKContainer(identifier: "iCloud.com.goodvibez.vowplanner")
let privateDB = container.privateCloudDatabase
let publicDB = container.publicCloudDatabase

// Test 1: Save a test Wedding record
func testSaveWedding() async {
    print("Testing CloudKit save...")
    let record = CKRecord(recordType: "Wedding")
    record["weddingId"] = UUID().uuidString
    record["coupleNames"] = "Test Wedding"
    record["date"] = Date() as CKRecordValue
    record["location"] = "Test Location"
    
    do {
        let savedRecord = try await privateDB.save(record)
        print("✅ Wedding saved: \(savedRecord.recordID.recordName)")
    } catch {
        print("❌ Error saving Wedding: \(error)")
        print("   This usually means CloudKit isn't available")
        print("   - Check iCloud account signed in")
        print("   - Try on real device, not simulator")
    }
}

// Test 2: Save a CoPlanner record (public database)
func testSaveCoPlanner() async {
    print("\nTesting CoPlanner save...")
    let record = CKRecord(recordType: "CoPlanner")
    record["code"] = "TEST123"
    record["weddingId"] = UUID().uuidString
    record["createdAt"] = Date() as CKRecordValue
    
    do {
        let savedRecord = try await publicDB.save(record)
        print("✅ CoPlanner saved: \(savedRecord.recordID.recordName)")
    } catch {
        print("❌ Error saving CoPlanner: \(error)")
    }
}

// Run tests
Task {
    await testSaveWedding()
    await testSaveCoPlanner()
    print("\n=== Test Complete ===")
}
