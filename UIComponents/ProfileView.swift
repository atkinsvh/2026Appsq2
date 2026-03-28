import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct ProfileView: View {
    @EnvironmentObject var appState: AppState
    @Binding var showHome: Bool
    @State private var coupleNames: String = ""
    @State private var showingEditProfile = false
    @State private var notificationsEnabled = true
    @State private var showingResetAlert = false
    @State private var lastTapTime: TimeInterval = 0
    @State private var tapCount = 0
    @State private var showingTestPanel = false
    
    init(showHome: Binding<Bool> = .constant(false)) {
        self._showHome = showHome
    }
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        ZStack {
                            Circle()
                                .fill(Color.pink.opacity(0.2))
                                .frame(width: 70, height: 70)
                            Image(systemName: "person.fill")
                                .font(.title)
                                .foregroundColor(.pink)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(appState.weddingDetails.coupleNames.isEmpty ? "Your Names" : appState.weddingDetails.coupleNames)
                                .font(.headline)
                            Text("Wedding Planner")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Image("HeartSmall")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 44, height: 44)
                    }
                    .padding(.vertical, 8)
                }
                
                Section {
                    HStack {
                        Image("SettingsIcon")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 20, height: 20)
                            .foregroundColor(.pink)
                        Text("Settings")
                            .font(.headline)
                    }
                    
                    NavigationLink(destination: WeddingDetailsView()) {
                        Label("Wedding Info", systemImage: "heart.fill")
                    }
                }

                if !appState.weddingMemberships.isEmpty {
                    Section("My Weddings") {
                        ForEach(appState.weddingMemberships) { wedding in
                            Button(action: {
                                Task {
                                    await appState.switchWedding(to: wedding.weddingId)
                                }
                            }) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(wedding.coupleNames.isEmpty ? "Untitled Wedding" : wedding.coupleNames)
                                            .foregroundColor(.primary)
                                        Text("\(wedding.weddingDate, formatter: dateFormatter) • \(wedding.role.rawValue.capitalized)")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    if appState.weddingId == wedding.weddingId {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.green)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                
                Section("Notifications") {
                    Toggle(isOn: $notificationsEnabled) {
                        Label("Push Notifications", systemImage: "bell.fill")
                    }
                    .tint(.pink)
                }
                
                Section("Data") {
                    Button(action: exportData) {
                        Label("Export All Data", systemImage: "square.and.arrow.up")
                    }
                    .foregroundColor(.primary)
                    
                    Button(action: exportGuestListCSV) {
                        Label("Export Guest List (CSV)", systemImage: "person.3")
                    }
                    .foregroundColor(.primary)
                    
                    Button(action: { showingResetAlert = true }) {
                        Label("Reset All Data", systemImage: "trash")
                    }
                    .foregroundColor(.red)
                }
                
                Section("Sync & Backup") {
                    HStack {
                        Image(systemName: appState.cloudKitSync.isOnline ? "wifi" : "wifi.slash")
                            .foregroundColor(appState.cloudKitSync.isOnline ? .green : .red)
                        Text(appState.cloudKitSync.isOnline ? "Connected" : "Offline")
                            .foregroundColor(appState.cloudKitSync.isOnline ? .primary : .secondary)
                        Spacer()
                        if let lastSync = appState.cloudKitSync.lastSyncDate {
                            Text("Last: \(lastSync, formatter: timeFormatter)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Button(action: forceSync) {
                        Label("Sync Now", systemImage: "arrow.triangle.2.circlepath")
                    }
                    .disabled(!appState.cloudKitSync.isOnline)
                    
                    if let error = appState.cloudKitSync.syncError {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                    }
                }
                
                Section("Invitation Codes") {
                    NavigationLink(destination: InvitationCodesView()) {
                        Label("Manage Codes", systemImage: "qrcode")
                    }
                }
                
                Section("Testing") {
                    Button(action: {
                        appState.enterGuestMode(with: "TEST01", rsvp: GuestRSVP(invitationCode: "TEST01", guestName: "", rsvpStatus: .noResponse))
                        appState.onboardingCompleted = true
                    }) {
                        Label("Switch to Guest Mode", systemImage: "person.2")
                    }
                    .foregroundColor(.blue)
                }
                
                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                    
                    Link(destination: URL(string: "https://vowplanner.goodvibez.life/privacy")!) {
                        Label("Privacy Policy", systemImage: "lock.shield")
                    }
                    
                    Link(destination: URL(string: "https://vowplanner.goodvibez.life/terms")!) {
                        Label("Terms of Service", systemImage: "doc.text")
                    }
                }
                
                Section {
                    Button(action: signOut) {
                        HStack {
                            Spacer()
                            Text("Sign Out")
                                .fontWeight(.medium)
                            Spacer()
                        }
                    }
                    .foregroundColor(.red)
                }
                
                Section("Cloud Sync") {
                    SyncStatusView()
                }
                
                // Hidden test section - triple tap the footer to reveal
                Section {
                    HStack {
                        Spacer()
                        Text("☁️")
                            .font(.caption)
                            .opacity(0.3)
                            .gesture(
                                TapGesture(count: 3)
                                    .onEnded {
                                        showingTestPanel = true
                                    }
                            )
                        Spacer()
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("Profile")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { showHome = true }) {
                        HStack(spacing: 4) {
                            Image(systemName: "house.fill")
                            Text("Home")
                        }
                        .foregroundColor(Color("AccentColor"))
                    }
                }
            }
            .alert("Reset All Data?", isPresented: $showingResetAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Reset", role: .destructive) {
                    resetAllData()
                }
            } message: {
                Text("This will delete all your wedding planning data. This action cannot be undone.")
            }
            .sheet(isPresented: $showingTestPanel) {
                TestPanelView()
            }
            .task {
                appState.fetchWeddingsForCurrentUser()
            }
        }
    }
    
    private func exportData() {
        let guests = DataStore.shared.load([Guest].self, from: "guests.json") ?? []
        let vendors = DataStore.shared.load([Vendor].self, from: "vendors.json") ?? []
        let categories = DataStore.shared.load([BudgetCategory].self, from: "budget_categories.json") ?? []
        let timelineItems = DataStore.shared.load([TimelineItem].self, from: "timeline.json") ?? []
        
        let exportData: [String: Any] = [
            "weddingDetails": [
                "coupleNames": appState.weddingDetails.coupleNames,
                "date": ISO8601DateFormatter().string(from: appState.weddingDetails.date),
                "location": appState.weddingDetails.location
            ],
            "guests": guests.map { ["name": $0.name, "email": $0.email ?? "", "rsvpStatus": $0.rsvpStatus.rawValue, "side": $0.side.rawValue, "household": $0.household ?? ""] },
            "vendors": vendors.map { ["name": $0.name, "category": $0.category, "email": $0.email ?? "", "phone": $0.phone ?? "", "website": $0.website ?? ""] },
            "budget": [
                "categories": categories.map { ["name": $0.name, "allocated": $0.allocated, "spent": $0.spent] },
                "totalAllocated": categories.reduce(0) { $0 + $1.allocated },
                "totalSpent": categories.reduce(0) { $0 + $1.spent }
            ],
            "timeline": timelineItems.map { ["title": $0.title, "dueDate": ISO8601DateFormatter().string(from: $0.dueDate), "completed": $0.completed] },
            "exportDate": ISO8601DateFormatter().string(from: Date()),
            "appVersion": "1.0.0"
        ]
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: exportData, options: .prettyPrinted)
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("VowPlanner_Export.json")
            try jsonData.write(to: tempURL)
            
            let activityVC = UIActivityViewController(activityItems: [tempURL], applicationActivities: nil)
            
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let rootVC = windowScene.windows.first?.rootViewController {
                rootVC.present(activityVC, animated: true)
            }
        } catch {
            print("Export failed: \(error)")
        }
    }
    
    private func exportGuestListCSV() {
        let guests = DataStore.shared.load([Guest].self, from: "guests.json") ?? []
        let csvContent = guests.generateCSV()
        
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("GuestList.csv")
        do {
            try csvContent.write(to: tempURL, atomically: true, encoding: .utf8)
            
            let activityVC = UIActivityViewController(activityItems: [tempURL], applicationActivities: nil)
            
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let rootVC = windowScene.windows.first?.rootViewController {
                rootVC.present(activityVC, animated: true)
            }
        } catch {
            print("CSV export failed: \(error)")
        }
    }
    
    private func forceSync() {
        Task {
            appState.cloudKitSync.isSyncing = true
            await appState.refreshFromCloudKit()
            appState.cloudKitSync.lastSyncDate = Date()
            appState.cloudKitSync.isSyncing = false
        }
    }
    
    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }

    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter
    }
    
    private func signOut() {
        appState.exitGuestMode()
        appState.weddingId = nil
        appState.isCoPlanner = false
        appState.onboardingCompleted = false
    }
    
    private func resetAllData() {
        let fileManager = FileManager.default
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        
        let filesToDelete = [
            "guests.json",
            "vendors.json",
            "timeline.json",
            "budget_categories.json",
            "wedding.json",
            "couplelife.json"
        ]
        
        for file in filesToDelete {
            let fileURL = documentsURL.appendingPathComponent(file)
            try? fileManager.removeItem(at: fileURL)
        }
        
        appState.weddingDetails = WeddingDetails(coupleNames: "", date: Date(), location: "")
        appState.weddingId = nil
        appState.isCoPlanner = false
        appState.exitGuestMode()
        appState.onboardingCompleted = false
    }
}

// Helper struct for managing invitation codes
struct InvitationCodesView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var coPlannerCode: String = ""
    @State private var guestCodes: [String] = []
    
    var body: some View {
        NavigationStack {
            List {
                Section("Co-Planner Code") {
                    if coPlannerCode.isEmpty {
                        Text("No co-planner code generated")
                            .foregroundColor(.secondary)
                    } else {
                        HStack {
                            Text(coPlannerCode)
                                .font(.system(.body, design: .monospaced))
                                .bold()
                            Spacer()
                            Button(action: { copyCode(coPlannerCode) }) {
                                Image(systemName: "doc.on.doc")
                            }
                        }
                    }
                }
                
                Section("Guest Codes (\(guestCodes.count))") {
                    if guestCodes.isEmpty {
                        Text("Create guests in the Guests tab")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(guestCodes, id: \.self) { code in
                            HStack {
                                Text(code)
                                    .font(.system(.body, design: .monospaced))
                                Spacer()
                                Button(action: { copyCode(code) }) {
                                    Image(systemName: "doc.on.doc")
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Invitation Codes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .onAppear {
                loadCodes()
            }
        }
    }
    
    private func loadCodes() {
        // Load co-planner code
        if let codes = DataStore.shared.load([InvitationCode].self, from: "co_planner_codes.json"),
           let firstCode = codes.first {
            coPlannerCode = firstCode.code
        }
        
        // Load guest codes
        if let codes = DataStore.shared.load([InvitationCode].self, from: "invitation_codes.json") {
            guestCodes = codes.map { $0.code }
        }
    }
    
    private func copyCode(_ code: String) {
        #if canImport(UIKit)
        UIPasteboard.general.string = code
        #endif
    }
}

// MARK: - Test Panel for CloudKit Schema Creation

struct TestPanelView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var testStatus: [String] = []
    @State private var isRunning = false
    
    var body: some View {
        NavigationStack {
            List {
                Section("CloudKit Schema Test") {
                    Button(action: runAllTests) {
                        HStack {
                            Image(systemName: "play.fill")
                            Text("Run All Tests")
                                .fontWeight(.bold)
                        }
                        .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.pink)
                    .cornerRadius(12)
                    .disabled(isRunning)
                }
                
                Section("Test Status") {
                    if testStatus.isEmpty {
                        Text("Tap 'Run All Tests' to trigger CloudKit schema creation")
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding()
                    } else {
                        ForEach(testStatus, id: \.self) { status in
                            HStack {
                                Image(systemName: status.contains("✅") ? "checkmark.circle.fill" : 
                                               status.contains("❌") ? "xmark.circle.fill" : "circle")
                                    .foregroundColor(status.contains("✅") ? .green : 
                                                     status.contains("❌") ? .red : .gray)
                                Text(status)
                                    .font(.caption)
                            }
                        }
                    }
                }
                
                Section("Instructions") {
                    Text("1. Tap 'Run All Tests'\n2. Wait for completion\n3. Check CloudKit Dashboard\n4. Deploy schema to production")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("CloudKit Test")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
    
    private func runAllTests() {
        isRunning = true
        testStatus.removeAll()
        
        Task {
            // Test 1: Create Wedding + normalized invitation verification baseline
            await MainActor.run { testStatus.append("Creating wedding...") }
            let weddingId = UUID()
            let weddingDetails = WeddingDetails(
                coupleNames: "Test Wedding",
                date: Date(),
                location: "Test Location"
            )
            do {
                _ = try await appState.cloudKitSync.saveWedding(weddingDetails, weddingId: weddingId)
                let schemaResult = try await appState.cloudKitSync.runSchemaPreparationTest(weddingId: weddingId)
                appState.weddingId = weddingId
                appState.weddingDetails = weddingDetails
                await MainActor.run {
                    testStatus.append("✅ Wedding saved to CloudKit")
                    testStatus.append("✅ Schema prep + invitation verification completed for code: \(schemaResult.invitationCode)")
                }
            } catch {
                await MainActor.run { testStatus.append("❌ Wedding/schema prep failed: \(error.localizedDescription)") }
            }
            
            // Test 2: Generate Co-Planner Code
            await MainActor.run { testStatus.append("Generating co-planner code...") }
            do {
                let code = try await appState.cloudKitSync.generateCoPlannerCode(weddingId: weddingId)
                await MainActor.run { testStatus.append("✅ Co-Planner code: \(code)") }
            } catch {
                await MainActor.run { testStatus.append("❌ Co-planner code failed: \(error.localizedDescription)") }
            }
            
            // Test 3: Save Guest
            await MainActor.run { testStatus.append("Creating guest...") }
            let testGuest = Guest(
                name: "Test Guest",
                email: "test@guest.com",
                phone: "555-1234",
                side: .both,
                rsvpStatus: .attending,
                mealChoice: "Chicken",
                dietaryNotes: "None",
                partySize: 2,
                invitationCode: "TEST123"
            )
            do {
                try await appState.cloudKitSync.saveGuests([testGuest], weddingId: weddingId)
                await MainActor.run { testStatus.append("✅ Guest saved to CloudKit") }
            } catch {
                await MainActor.run { testStatus.append("❌ Guest failed: \(error.localizedDescription)") }
            }
            
            // Test 3b: Save Invitation Code
            await MainActor.run { testStatus.append("Creating invitation code...") }
            var testInvitation = InvitationCode(
                code: "TEST\(Int.random(in: 100...999))",
                weddingId: weddingId,
                coupleNames: "Test Wedding",
                date: Date(),
                location: "Test Location",
                guestId: testGuest.id,
                guestName: testGuest.name,
                partySize: 2,
                phoneNumber: testGuest.phone
            )
            testInvitation.rsvpStatus = .attending
            testInvitation.mealChoice = "Chicken"
            do {
                try await appState.cloudKitSync.saveInvitationCode(testInvitation)
                await MainActor.run { testStatus.append("✅ Invitation code saved to CloudKit") }
            } catch {
                await MainActor.run { testStatus.append("❌ Invitation code failed: \(error.localizedDescription)") }
            }
            
            // Test 4: Save Budget Category
            await MainActor.run { testStatus.append("Creating budget category...") }
            let testCategory = BudgetCategory(
                id: UUID(),
                name: "Test Category",
                allocated: 5000,
                spent: 1000
            )
            do {
                try await appState.cloudKitSync.saveBudget([testCategory], weddingId: weddingId)
                await MainActor.run { testStatus.append("✅ Budget saved to CloudKit") }
            } catch {
                await MainActor.run { testStatus.append("❌ Budget failed: \(error.localizedDescription)") }
            }
            
            // Test 5: Save Vendor
            await MainActor.run { testStatus.append("Creating vendor...") }
            let testVendor = Vendor(
                id: UUID(),
                name: "Test Vendor",
                category: "Catering",
                phone: "555-5678",
                email: "vendor@test.com",
                website: "https://test.com",
                notes: "Test notes"
            )
            do {
                try await appState.cloudKitSync.saveVendors([testVendor], weddingId: weddingId)
                await MainActor.run { testStatus.append("✅ Vendor saved to CloudKit") }
            } catch {
                await MainActor.run { testStatus.append("❌ Vendor failed: \(error.localizedDescription)") }
            }
            
            // Test 6: Save Guest RSVP (Public)
            await MainActor.run { testStatus.append("Creating guest RSVP...") }
            let testRSVP = GuestRSVP(
                invitationCode: "TEST123",
                guestName: "Test Guest",
                rsvpStatus: .attending,
                mealChoice: "Chicken",
                dietaryNotes: "None",
                partySize: 2
            )
            do {
                try await appState.cloudKitSync.saveGuestRSVP(testRSVP)
                await MainActor.run { testStatus.append("✅ Guest RSVP saved to CloudKit") }
            } catch {
                await MainActor.run { testStatus.append("❌ Guest RSVP failed: \(error.localizedDescription)") }
            }
            
            // Test 7: Save Event Photo (creates schema)
            await MainActor.run { testStatus.append("Creating event photo...") }
            do {
                let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("cloudkit-test-photo.txt")
                try "test photo".write(to: tempURL, atomically: true, encoding: .utf8)
                _ = try await appState.cloudKitSync.saveEventPhoto(
                    imageURL: tempURL,
                    weddingId: weddingId,
                    invitationCode: testInvitation.code,
                    guestName: testGuest.name,
                    caption: "Schema creation test"
                )
                await MainActor.run { testStatus.append("✅ Event photo saved to CloudKit") }
            } catch {
                await MainActor.run { testStatus.append("❌ Event photo failed: \(error.localizedDescription)") }
            }
            
            await MainActor.run {
                testStatus.append("🎉 All tests complete!")
                testStatus.append("Check CloudKit Dashboard to see new record types")
                isRunning = false
            }
        }
    }
}
