import SwiftUI
import WebKit
#if canImport(UIKit)
import UIKit
#endif

// ─────────────────────────────────────────────
// FIXED BUG-06 — WebsiteView.loadSavedWebsite
// Was: synchronous Data(contentsOf:) on the main thread → UI freeze on large HTML files.
// Fix: move the disk read to a background Task, then publish results on MainActor.
// ─────────────────────────────────────────────
struct WebsiteView: View {
    @EnvironmentObject var appState: AppState
    @State private var generatedHTML: String = ""
    @State private var isGenerating = false
    @State private var showingPreview = false
    @State private var showingShare = false
    @State private var selectedTemplate: WebsiteTemplate = .classic
    @State private var generatedWebsiteURL: URL?
    @State private var generationErrorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    headerSection
                    templateSection
                    previewSection
                    generateButton
                }
                .padding()
            }
            .navigationTitle("Wedding Website")
            .sheet(isPresented: $showingPreview) {
                WebsitePreviewSheet(html: generatedHTML)
            }
            .sheet(isPresented: $showingShare) {
                if let url = generatedWebsiteURL {
                    ShareSheet(items: [url])
                }
            }
            .onAppear {
                loadSavedWebsite()
            }
        }
    }

    private var headerSection: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "globe")
                    .font(.system(size: 50))
                    .foregroundColor(.pink)
                Image("FloralInsignia")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 60, height: 60)
            }
            Text("Create Your Wedding Website")
                .font(.title2).fontWeight(.bold)
            Text("Share your wedding details with guests")
                .font(.subheadline).foregroundColor(.secondary).multilineTextAlignment(.center)
        }
        .padding(.vertical)
    }

    private var templateSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Choose a Template").font(.headline)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(WebsiteTemplate.allCases, id: \.self) { template in
                        TemplateCard(
                            name: template.rawValue,
                            image: template.icon,
                            isSelected: selectedTemplate == template
                        ) {
                            withAnimation(.spring(response: 0.3)) { selectedTemplate = template }
                        }
                    }
                }
            }
        }
    }

    private var previewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Website Preview").font(.headline)
                Spacer()
                if !generatedHTML.isEmpty {
                    Button("View") { showingPreview = true }
                }
            }
            VStack(spacing: 8) {
                previewRow("Couple Names",
                           appState.weddingDetails.coupleNames.isEmpty ? "Not set" : appState.weddingDetails.coupleNames)
                previewRow("Wedding Date", weddingDateText)
                previewRow("Location",
                           appState.weddingDetails.location.isEmpty ? "Not set" : appState.weddingDetails.location)
            }
        }
    }

    private func previewRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).font(.caption).foregroundColor(.secondary)
            Spacer()
            Text(value).font(.body).lineLimit(1)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }

    private var generateButton: some View {
        VStack(spacing: 12) {
            Button(action: generateWebsite) {
                HStack {
                    if isGenerating { ProgressView().tint(.white) }
                    else { Image(systemName: "wand.and.stars") }
                    Text(isGenerating ? "Generating..." : "Generate Website")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color("AccentColor"))
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .disabled(isGenerating)

            if !generatedHTML.isEmpty {
                Button(action: { showingShare = true }) {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                        Text("Share Website")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(.systemGray5))
                    .foregroundColor(.primary)
                    .cornerRadius(12)
                }
            }

            if let generationErrorMessage {
                Text(generationErrorMessage)
                    .font(.footnote)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var weddingDateText: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        return formatter.string(from: appState.weddingDetails.date)
    }

    private func generateWebsite() {
        isGenerating = true
        generationErrorMessage = nil

        let guests = appState.dataStore.load([Guest].self, from: "guests.json") ?? []
        let attendingGuests = guests.filter { $0.rsvpStatus == .attending }

        let request = WebsiteGenerationRequest(
            coupleNames: appState.weddingDetails.coupleNames,
            date: weddingDateText,
            location: appState.weddingDetails.location,
            attendingGuests: attendingGuests,
            template: selectedTemplate
        )

        let result = WebsiteService.shared.generateWebsite(request: request)
        switch result {
        case .success(let generatedWebsite):
            generatedHTML = generatedWebsite.html
            generatedWebsiteURL = generatedWebsite.fileURL
        case .failure(let error):
            generationErrorMessage = error.localizedDescription
        }

        isGenerating = false
    }

    // BUG-06 FIX: Was `Data(contentsOf: url)` called synchronously on the main
    // thread inside `.onAppear`. For a large HTML file this freezes the UI while
    // the disk read completes. Moved to a background Task with MainActor publish.
    private func loadSavedWebsite() {
        Task.detached(priority: .userInitiated) {
            let url = FileManager.default
                .urls(for: .documentDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("wedding_website.html")

            guard let data = try? Data(contentsOf: url),
                  let html = String(data: data, encoding: .utf8) else { return }

            await MainActor.run {
                self.generatedHTML = html
                self.generatedWebsiteURL = url
            }
        }
    }
}

struct TemplateCard: View {
    let name: String
    let image: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: image)
                    .font(.title)
                    .foregroundColor(isSelected ? .white : .secondary)
                Text(name)
                    .font(.caption)
                    .fontWeight(isSelected ? .semibold : .regular)
                    .foregroundColor(isSelected ? .white : .primary)
            }
            .frame(width: 100, height: 80)
            .background(isSelected ? Color("AccentColor") : Color(.systemGray6))
            .cornerRadius(12)
        }
    }
}

struct WebsitePreviewSheet: View {
    let html: String
    @Environment(\.dismiss) private var dismiss
    @StateObject private var webViewModel = WebViewModel()

    var body: some View {
        NavigationStack {
            WebView(webViewModel: webViewModel, html: html)
                .ignoresSafeArea()
                .navigationTitle("Preview")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close") { dismiss() }
                    }
                    ToolbarItem(placement: .primaryAction) {
                        Button(action: { webViewModel.reload() }) {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                }
        }
    }
}

@MainActor
class WebViewModel: ObservableObject {
    var webView: WKWebView?
    func reload() { webView?.reload() }
}

struct WebView: UIViewRepresentable {
    @ObservedObject var webViewModel: WebViewModel
    let html: String

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webViewModel.webView = webView
        webView.loadHTMLString(html, baseURL: nil)
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        webView.loadHTMLString(html, baseURL: nil)
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}


// ─────────────────────────────────────────────────────────────────────────────
// FIXED BUG-01 — GuestHomeView.guestHeader
// Was: `.background( LinearGradient(...) }` — closing brace instead of
//      closing parenthesis, causing a compile error.
// FIXED BUG-05 — GuestPhotoWall.onChange
// Was: `.onChange(of: selectedPhotoItem != nil) { _, hasSelection in ...}`
//      — Bool-comparison form deprecated in iOS 17, could double-trigger uploads.
// ─────────────────────────────────────────────────────────────────────────────

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

    // BUG-01 FIX: the closing bracket for .background() was `}` instead of `)`.
    private var guestHeader: some View {
        VStack(spacing: 12) {
            Image("HeartLarge")
                .resizable()
                .scaledToFit()
                .frame(width: 90, height: 90)

            Text("Welcome, \(guestDisplayName)")
                .font(.title2).fontWeight(.bold)

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
        )                      // ← BUG-01 FIX: was `}` here
        .cornerRadius(20)
    }

    private var codeCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your Guest Code").font(.headline)
            HStack {
                Text(appState.currentInvitationCode ?? "Not available")
                    .font(.system(.title3, design: .monospaced))
                    .fontWeight(.bold)
                    .foregroundColor(.pink)
                Spacer()
                Button(action: copyCode) { Image(systemName: "doc.on.doc") }
                Button(action: { showingShareSheet = true }) { Image(systemName: "square.and.arrow.up") }
            }
            Text("Keep this code handy for RSVP updates and event check-in.")
                .font(.caption).foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
    }

    private var eventInfoCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Event Details").font(.headline)
            GuestDetailRow(label: "Couple",
                           value: appState.weddingDetails.coupleNames.isEmpty
                               ? "Wedding Event" : appState.weddingDetails.coupleNames)
            GuestDetailRow(label: "Date",   value: formattedWeddingDate)
            GuestDetailRow(label: "Location",
                           value: appState.weddingDetails.location.isEmpty
                               ? "Location will be shared soon" : appState.weddingDetails.location)
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
            Text("Your RSVP").font(.headline)
            GuestDetailRow(label: "Status", value: rsvpStatusText)
            GuestDetailRow(label: "Meal",
                           value: appState.guestRSVP?.mealChoice ?? invitation?.mealChoice ?? "Not selected")
            GuestDetailRow(label: "Notes",
                           value: appState.guestRSVP?.dietaryNotes ?? invitation?.dietaryNotes ?? "No notes submitted")
            GuestDetailRow(label: "Party Size",
                           value: "\(appState.guestRSVP?.partySize ?? invitation?.partySize ?? 1)")
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
    }

    private var itineraryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Event Itinerary").font(.headline)
                Spacer()
                Image(systemName: "calendar.badge.clock").foregroundColor(.pink)
            }
            if eventDayItems.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Arrive 30 minutes early").font(.subheadline).fontWeight(.semibold)
                    Text("Ceremony date: \(formattedWeddingDate)").font(.caption).foregroundColor(.secondary)
                    Text(appState.weddingDetails.location.isEmpty
                         ? "Venue details will appear here when available."
                         : "Reception to follow at \(appState.weddingDetails.location).")
                        .font(.caption).foregroundColor(.secondary)
                }
            } else {
                ForEach(eventDayItems, id: \.id) { item in
                    HStack(alignment: .top) {
                        Circle().fill(Color.pink).frame(width: 8, height: 8).padding(.top, 6)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.title).font(.subheadline).fontWeight(.semibold)
                            Text(item.dueDate.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption).foregroundColor(.secondary)
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

            Button(action: { appState.returnToGuestCodeEntry() }) {
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
        case .attending:  return "Attending"
        case .declined:   return "Declined"
        case .noResponse: return "Pending"
        }
    }

    private var shareMessage: String {
        let code = appState.currentInvitationCode ?? "Unavailable"
        let coupleNames = appState.weddingDetails.coupleNames.isEmpty
            ? "Wedding Event" : appState.weddingDetails.coupleNames
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
                var cachedInvitations = DataStore.shared.load([InvitationCode].self,
                                                              from: "invitation_codes.json") ?? []
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
                return abs(dueDay.timeIntervalSince(weddingDay)) <= 86_400
                    || $0.title.localizedCaseInsensitiveContains("wedding")
            }
            .sorted { $0.dueDate < $1.dueDate }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// GuestPhotoWall — BUG-05 FIX
// ─────────────────────────────────────────────────────────────────────────────
import PhotosUI

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
                Text("Shared Photo Wall").font(.headline)
                Spacer()
                Button(action: { Task { await loadPhotos() } }) {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(isLoading)
            }

            if canSharePhotos {
                TextField("Add a caption (optional)", text: $caption)
                    .textFieldStyle(.roundedBorder)

                PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                    Label(isUploading ? "Uploading Photo..." : "Share a Photo",
                          systemImage: "photo.on.rectangle.angled")
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
                    .font(.caption).foregroundColor(.secondary)
            }

            if let errorMessage, !errorMessage.isEmpty {
                Text(errorMessage).font(.caption).foregroundColor(.red)
            }

            if isLoading && photos.isEmpty {
                ProgressView("Loading photos...")
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 12)
            } else if photos.isEmpty {
                Text("No shared photos yet. Be the first guest to add one.")
                    .font(.caption).foregroundColor(.secondary)
            } else {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(photos, id: \.id) { photo in
                        VStack(alignment: .leading, spacing: 8) {
                            AsyncImage(url: photo.imageURL) { phase in
                                switch phase {
                                case .empty:
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 14).fill(Color(.systemGray6))
                                        ProgressView()
                                    }
                                case .success(let image):
                                    image.resizable().scaledToFill()
                                case .failure:
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 14).fill(Color(.systemGray6))
                                        Image(systemName: "photo").foregroundColor(.secondary)
                                    }
                                @unknown default:
                                    EmptyView()
                                }
                            }
                            .frame(height: 150)
                            .frame(maxWidth: .infinity)
                            .clipShape(RoundedRectangle(cornerRadius: 14))

                            Text(photo.guestName).font(.caption).fontWeight(.semibold)
                            if let cap = photo.caption, !cap.isEmpty {
                                Text(cap).font(.caption2).foregroundColor(.secondary).lineLimit(2)
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
        .task { await loadPhotos() }
        // BUG-05 FIX: was `.onChange(of: selectedPhotoItem != nil)` — Bool comparison
        // using the deprecated two-param closure form. This could double-fire and
        // trigger duplicate uploads. Now observes the Optional item directly.
        .onChange(of: selectedPhotoItem) { _, newItem in
            guard let newItem else { return }
            Task { await uploadPhoto(from: newItem) }
        }
    }

    private var canSharePhotos: Bool {
        appState.guestWeddingId != nil
            && !(appState.currentInvitationCode ?? "").isEmpty
            && !(appState.guestRSVP?.guestName ?? "").isEmpty
    }

    private func loadPhotos() async {
        guard let weddingId = appState.guestWeddingId else { photos = []; return }
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
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(UUID().uuidString).jpg")
        try data.write(to: tempURL, options: .atomic)
        return tempURL
    }
}

struct GuestDetailRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.caption).foregroundColor(.secondary)
                .frame(width: 84, alignment: .leading)
            Text(value).font(.subheadline).multilineTextAlignment(.leading)
            Spacer(minLength: 0)
        }
    }
}
