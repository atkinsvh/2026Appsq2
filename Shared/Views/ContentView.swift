import SwiftUI
import PhotosUI
#if canImport(UIKit)
import UIKit
#endif

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        Group {
            if !appState.onboardingCompleted {
                OnboardingView()
            } else if appState.isGuestMode {
                GuestModeEntryView()
            } else if appState.isGuestAccessOnly {
                GuestAccessGateView()
            } else {
                MainTabView()
            }
        }
    }
}


struct GuestAccessGateView: View {
    @EnvironmentObject var appState: AppState
    @State private var invitationCode: String = ""
    @State private var errorMessage: String?
    @State private var isVerifying = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                Image(systemName: "ticket.fill")
                    .font(.system(size: 56))
                    .foregroundColor(.pink)

                VStack(spacing: 8) {
                    Text("Guest Access")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("Enter your verified invitation code to continue to your guest space.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }

                TextField("ABC123", text: $invitationCode)
                    .font(.system(size: 34, weight: .bold, design: .monospaced))
                    .multilineTextAlignment(.center)
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.pink.opacity(0.2), lineWidth: 1)
                    )
                    .onChange(of: invitationCode) { _, newValue in
                        invitationCode = appState.normalizeInvitationCode(newValue)
                    }

                if let errorMessage, !errorMessage.isEmpty {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                }

                Button(action: verifyCode) {
                    HStack {
                        if isVerifying {
                            ProgressView()
                                .tint(.white)
                        }
                        Text(isVerifying ? "Verifying..." : "Open Guest Space")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(invitationCode.count == 6 && !isVerifying ? Color.pink : Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(14)
                }
                .disabled(invitationCode.count != 6 || isVerifying)

                Spacer()
            }
            .padding(24)
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Guest")
        }
    }

    private func verifyCode() {
        errorMessage = nil
        isVerifying = true

        Task {
            do {
                let invitation = try await appState.verifyGuestInvitationCode(invitationCode)
                await MainActor.run {
                    appState.enterGuestMode(with: invitation)
                    isVerifying = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isVerifying = false
                }
            }
        }
    }
}

struct GuestModeEntryView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        if let rsvp = appState.guestRSVP,
           rsvp.rsvpStatus != .noResponse {
            GuestHomeView()
        } else {
            SequentialGuestRSVPView()
        }
    }
}

struct GuestHomeView: View {
    @EnvironmentObject var appState: AppState
    @State private var invitation: InvitationCode?
    @State private var eventDayItems: [TimelineItem] = []
    @State private var showingShareSheet = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    guestHeader
                    codeCard
                    eventInfoCard
                    rsvpSummaryCard
                    itineraryCard
                    GuestPhotoWall()
                    actionButtons
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Guest Home")
            .sheet(isPresented: $showingShareSheet) {
                ShareSheet(items: [shareMessage])
            }
            .task {
                await refreshGuestContext()
            }
        }
    }
    
    private var guestHeader: some View {
        VStack(spacing: 12) {
            Image("HeartLarge")
                .resizable()
                .scaledToFit()
                .frame(width: 90, height: 90)
            
            Text("Welcome, \(guestDisplayName)")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Your RSVP is saved. You can check your details, event reminders, and share photos here.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(
            LinearGradient(
                colors: [Color.pink.opacity(0.18), Color.orange.opacity(0.12)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        .cornerRadius(20)
    }
    
    private var codeCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your Guest Code")
                .font(.headline)
            
            HStack {
                Text(appState.currentInvitationCode ?? "Not available")
                    .font(.system(.title3, design: .monospaced))
                    .fontWeight(.bold)
                    .foregroundColor(.pink)
                Spacer()
                Button(action: copyCode) {
                    Image(systemName: "doc.on.doc")
                }
                Button(action: { showingShareSheet = true }) {
                    Image(systemName: "square.and.arrow.up")
                }
            }
            
            Text("Keep this code handy for RSVP updates and event check-in.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
    }
    
    private var eventInfoCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Event Details")
                .font(.headline)
            
            GuestDetailRow(label: "Couple", value: appState.weddingDetails.coupleNames.isEmpty ? "Wedding Event" : appState.weddingDetails.coupleNames)
            GuestDetailRow(label: "Date", value: formattedWeddingDate)
            GuestDetailRow(label: "Location", value: appState.weddingDetails.location.isEmpty ? "Location will be shared soon" : appState.weddingDetails.location)
            if let invitation {
                GuestDetailRow(label: "Party Size", value: "\(invitation.partySize)")
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
    }
    
    private var rsvpSummaryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your RSVP")
                .font(.headline)
            
            GuestDetailRow(label: "Status", value: rsvpStatusText)
            GuestDetailRow(label: "Meal", value: appState.guestRSVP?.mealChoice ?? invitation?.mealChoice ?? "Not selected")
            GuestDetailRow(label: "Notes", value: appState.guestRSVP?.dietaryNotes ?? invitation?.dietaryNotes ?? "No notes submitted")
            GuestDetailRow(label: "Party Size", value: "\(appState.guestRSVP?.partySize ?? invitation?.partySize ?? 1)")
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
    }
    
    private var itineraryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Event Itinerary")
                    .font(.headline)
                Spacer()
                Image(systemName: "calendar.badge.clock")
                    .foregroundColor(.pink)
            }
            
            if eventDayItems.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Arrive 30 minutes early")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Text("Ceremony date: \(formattedWeddingDate)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(appState.weddingDetails.location.isEmpty ? "Venue details will appear here when available." : "Reception to follow at \(appState.weddingDetails.location).")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else {
                ForEach(eventDayItems, id: \.id) { item in
                    HStack(alignment: .top) {
                        Circle()
                            .fill(Color.pink)
                            .frame(width: 8, height: 8)
                            .padding(.top, 6)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.title)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            Text(item.dueDate.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
    }
    
    private var actionButtons: some View {
        VStack(spacing: 12) {
            Button(action: {
                let existing = appState.guestRSVP
                appState.guestRSVP = GuestRSVP(
                    invitationCode: appState.currentInvitationCode ?? existing?.invitationCode ?? "",
                    guestName: existing?.guestName ?? invitation?.guestName ?? "",
                    rsvpStatus: .noResponse,
                    mealChoice: existing?.mealChoice ?? invitation?.mealChoice,
                    dietaryNotes: existing?.dietaryNotes ?? invitation?.dietaryNotes,
                    partySize: existing?.partySize ?? invitation?.partySize ?? 1
                )
            }) {
                Label("Edit RSVP", systemImage: "pencil")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(.systemGray6))
                    .foregroundColor(.primary)
                    .cornerRadius(12)
            }
            
            Button(action: {
                appState.returnToGuestCodeEntry()
            }) {
                Label("Use Another Code", systemImage: "arrow.counterclockwise")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.red.opacity(0.12))
                    .foregroundColor(.red)
                    .cornerRadius(12)
            }
        }
    }
    
    private var guestDisplayName: String {
        let name = appState.guestRSVP?.guestName ?? invitation?.guestName ?? ""
        return name.isEmpty ? "Guest" : name
    }
    
    private var formattedWeddingDate: String {
        appState.weddingDetails.date.formatted(date: .complete, time: .omitted)
    }
    
    private var rsvpStatusText: String {
        switch appState.guestRSVP?.rsvpStatus ?? invitation?.rsvpStatus ?? .noResponse {
        case .attending:
            return "Attending"
        case .declined:
            return "Declined"
        case .noResponse:
            return "Pending"
        }
    }
    
    private var shareMessage: String {
        let code = appState.currentInvitationCode ?? "Unavailable"
        let coupleNames = appState.weddingDetails.coupleNames.isEmpty ? "Wedding Event" : appState.weddingDetails.coupleNames
        return """
        \(coupleNames)
        Guest code: \(code)
        Date: \(formattedWeddingDate)
        Location: \(appState.weddingDetails.location)
        """
    }
    
    private func copyCode() {
        #if canImport(UIKit)
        UIPasteboard.general.string = appState.currentInvitationCode
        #endif
    }
    
    private func refreshGuestContext() async {
        eventDayItems = loadEventDayItems()
        
        guard let code = appState.currentInvitationCode else { return }
        
        if let localInvitations = DataStore.shared.load([InvitationCode].self, from: "invitation_codes.json"),
           let localInvitation = localInvitations.first(where: { $0.code == code }) {
            invitation = localInvitation
            appState.guestWeddingId = localInvitation.weddingId
        }
        
        do {
            if let cloudInvitation = try await appState.fetchInvitationCodeFromCloud(code) {
                invitation = cloudInvitation
                appState.guestWeddingId = cloudInvitation.weddingId
                if appState.weddingDetails.coupleNames.isEmpty {
                    appState.weddingDetails = WeddingDetails(
                        coupleNames: cloudInvitation.coupleNames,
                        date: cloudInvitation.weddingDate,
                        location: cloudInvitation.weddingLocation
                    )
                }
                var cachedInvitations = DataStore.shared.load([InvitationCode].self, from: "invitation_codes.json") ?? []
                if let index = cachedInvitations.firstIndex(where: { $0.code == cloudInvitation.code }) {
                    cachedInvitations[index] = cloudInvitation
                } else {
                    cachedInvitations.append(cloudInvitation)
                }
                _ = DataStore.shared.save(cachedInvitations, to: "invitation_codes.json")
                if appState.guestRSVP == nil || appState.guestRSVP?.rsvpStatus == .noResponse {
                    appState.guestRSVP = GuestRSVP(
                        invitationCode: cloudInvitation.code,
                        guestName: cloudInvitation.guestName ?? "",
                        rsvpStatus: cloudInvitation.rsvpStatus ?? .noResponse,
                        mealChoice: cloudInvitation.mealChoice,
                        dietaryNotes: cloudInvitation.dietaryNotes,
                        partySize: cloudInvitation.partySize
                    )
                }
                eventDayItems = loadEventDayItems()
            }
        } catch {
            print("Failed to refresh guest invitation context: \(error)")
        }
    }
    
    private func loadEventDayItems() -> [TimelineItem] {
        let items = DataStore.shared.load([TimelineItem].self, from: "timeline.json") ?? []
        let weddingDay = Calendar.current.startOfDay(for: appState.weddingDetails.date)
        return items
            .filter {
                let dueDay = Calendar.current.startOfDay(for: $0.dueDate)
                return abs(dueDay.timeIntervalSince(weddingDay)) <= 86_400 || $0.title.localizedCaseInsensitiveContains("wedding")
            }
            .sorted { $0.dueDate < $1.dueDate }
    }
}

struct GuestDetailRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 84, alignment: .leading)
            Text(value)
                .font(.subheadline)
                .multilineTextAlignment(.leading)
            Spacer(minLength: 0)
        }
    }
}

struct GuestPhotoWall: View {
    @EnvironmentObject var appState: AppState
    @State private var photos: [EventPhoto] = []
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var caption: String = ""
    @State private var isLoading = false
    @State private var isUploading = false
    @State private var errorMessage: String?
    
    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Shared Photo Wall")
                    .font(.headline)
                Spacer()
                Button(action: {
                    Task { await loadPhotos() }
                }) {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(isLoading)
            }
            
            if canSharePhotos {
                TextField("Add a caption (optional)", text: $caption)
                    .textFieldStyle(.roundedBorder)
                
                PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                    Label(isUploading ? "Uploading Photo..." : "Share a Photo", systemImage: "photo.on.rectangle.angled")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.pink.opacity(0.12))
                        .foregroundColor(.pink)
                        .cornerRadius(12)
                }
                .disabled(isUploading)
            } else {
                Text("Photo sharing becomes available after the guest code is linked to a wedding and your RSVP is saved.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if let errorMessage, !errorMessage.isEmpty {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundColor(.red)
            }
            
            if isLoading && photos.isEmpty {
                ProgressView("Loading photos...")
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 12)
            } else if photos.isEmpty {
                Text("No shared photos yet. Be the first guest to add one.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(photos, id: \.id) { photo in
                        VStack(alignment: .leading, spacing: 8) {
                            AsyncImage(url: photo.imageURL) { phase in
                                switch phase {
                                case .empty:
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 14)
                                            .fill(Color(.systemGray6))
                                        ProgressView()
                                    }
                                case .success(let image):
                                    image
                                        .resizable()
                                        .scaledToFill()
                                case .failure:
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 14)
                                            .fill(Color(.systemGray6))
                                        Image(systemName: "photo")
                                            .foregroundColor(.secondary)
                                    }
                                @unknown default:
                                    EmptyView()
                                }
                            }
                            .frame(height: 150)
                            .frame(maxWidth: .infinity)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            
                            Text(photo.guestName)
                                .font(.caption)
                                .fontWeight(.semibold)
                            if let caption = photo.caption, !caption.isEmpty {
                                Text(caption)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .lineLimit(2)
                            }
                        }
                        .padding(10)
                        .background(Color(.systemBackground))
                        .cornerRadius(16)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .task {
            await loadPhotos()
        }
        .onChange(of: selectedPhotoItem != nil) { _, hasSelection in
            guard hasSelection, let newItem = selectedPhotoItem else { return }
            Task {
                await uploadPhoto(from: newItem)
            }
        }
    }
    
    private var canSharePhotos: Bool {
        appState.guestWeddingId != nil &&
        !(appState.currentInvitationCode ?? "").isEmpty &&
        !(appState.guestRSVP?.guestName ?? "").isEmpty
    }
    
    private func loadPhotos() async {
        guard let weddingId = appState.guestWeddingId else {
            photos = []
            return
        }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            photos = try await appState.cloudKitSync.fetchEventPhotos(weddingId: weddingId)
            errorMessage = nil
        } catch {
            errorMessage = "Could not load shared photos right now."
        }
    }
    
    private func uploadPhoto(from item: PhotosPickerItem) async {
        guard canSharePhotos,
              let weddingId = appState.guestWeddingId,
              let invitationCode = appState.currentInvitationCode,
              let guestName = appState.guestRSVP?.guestName,
              let data = try? await item.loadTransferable(type: Data.self) else {
            errorMessage = "Could not prepare that photo."
            return
        }
        
        isUploading = true
        defer {
            isUploading = false
            selectedPhotoItem = nil
        }
        
        do {
            let tempURL = try makeTemporaryPhotoURL(from: data)
            let photo = try await appState.cloudKitSync.saveEventPhoto(
                imageURL: tempURL,
                weddingId: weddingId,
                invitationCode: invitationCode,
                guestName: guestName,
                caption: caption.isEmpty ? nil : caption
            )
            photos.insert(photo, at: 0)
            caption = ""
            errorMessage = nil
        } catch {
            errorMessage = "Could not upload that photo."
        }
    }
    
    private func makeTemporaryPhotoURL(from data: Data) throws -> URL {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).jpg")
        try data.write(to: tempURL, options: .atomic)
        return tempURL
    }
}

struct RSVPFormView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    
    @State private var guestName: String = ""
    @State private var rsvpStatus: RSVPStatus = .noResponse
    @State private var mealChoice: String = ""
    @State private var dietaryNotes: String = ""
    @State private var partySize: Int = 1
    @State private var showingSuccess = false
    
    let weddingNames: String
    let weddingDate: Date
    let weddingLocation: String
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    headerSection
                    nameSection
                    rsvpSection
                    
                    if rsvpStatus == .attending {
                        detailsSection
                    }
                    
                    submitButton
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("You're Invited!")
            .navigationBarTitleDisplayMode(.large)
            .alert("RSVP Submitted!", isPresented: $showingSuccess) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text("Thank you for responding!")
            }
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            Image("HeartLarge")
                .resizable()
                .scaledToFit()
                .frame(width: 80, height: 80)
            
            Text(weddingNames)
                .font(.title)
                .fontWeight(.bold)
        }
    }
    
    private var nameSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your Name")
                .font(.headline)
            TextField("Enter your name", text: $guestName)
                .textFieldStyle(.plain)
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(12)
        }
    }
    
    private var rsvpSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Will you attend?")
                .font(.headline)
            
            HStack(spacing: 12) {
                Button(action: { rsvpStatus = .attending }) {
                    Text("Yes")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(rsvpStatus == .attending ? Color.green.opacity(0.2) : Color(.systemGray6))
                        .cornerRadius(12)
                }
                
                Button(action: { rsvpStatus = .declined }) {
                    Text("No")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(rsvpStatus == .declined ? Color.red.opacity(0.2) : Color(.systemGray6))
                        .cornerRadius(12)
                }
            }
        }
    }
    
    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Dinner Options")
                .font(.headline)
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(["Chicken", "Beef", "Fish", "Vegetarian"], id: \.self) { option in
                    Button(action: { mealChoice = option }) {
                        Text(option)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(mealChoice == option ? Color.pink.opacity(0.2) : Color(.systemGray6))
                            .cornerRadius(10)
                    }
                }
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Party Size: \(partySize)")
                    .font(.headline)
                Stepper("", value: $partySize, in: 1...5)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
            }
        }
    }
    
    private var submitButton: some View {
        Button(action: submitRSVP) {
            Text("Submit RSVP")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
                .background(guestName.isEmpty ? Color.gray : Color.pink)
                .foregroundColor(.white)
                .cornerRadius(16)
        }
        .disabled(guestName.isEmpty)
    }
    
    private func submitRSVP() {
        let code = appState.currentInvitationCode ?? ""
        let rsvp = GuestRSVP(
            invitationCode: code,
            guestName: guestName,
            rsvpStatus: rsvpStatus,
            mealChoice: rsvpStatus == .attending ? mealChoice : nil,
            dietaryNotes: dietaryNotes.isEmpty ? nil : dietaryNotes,
            partySize: partySize
        )
        
        appState.submitGuestRSVP(rsvp)
        showingSuccess = true
    }
}

struct MainTabView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        TabView {
            ProfileView(showHome: .constant(false))
                .tabItem {
                    Label("Profile", systemImage: "person.circle.fill")
                }
            
            DashboardView()
                .tabItem {
                    Label("Dashboard", systemImage: "heart.circle.fill")
                }
            
            GuestsView()
                .tabItem {
                    Label("Guests", systemImage: "person.3.fill")
                }
            
            BudgetView()
                .tabItem {
                    Label("Budget", systemImage: "creditcard.fill")
                }
            
            VendorsView()
                .tabItem {
                    Label("Vendors", systemImage: "bag.fill")
                }
            
            TimelineView()
                .tabItem {
                    Label("Timeline", systemImage: "calendar.badge.clock")
                }
            
            WebsiteView()
                .tabItem {
                    Label("Website", systemImage: "globe")
                }
        }
        .tint(Color("AccentColor"))
    }
}
#Preview {
    ContentView()
        .environmentObject(AppState())
}
