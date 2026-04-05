import SwiftUI
import Charts

struct GuestsView: View {
    @EnvironmentObject var appState: AppState
    @State private var guests: [Guest] = []
    @State private var filter: RSVPStatus? = nil
    @State private var showingAddGuest = false
    @State private var searchText = ""
    @State private var showingInviteSheet = false
    @State private var guestForInvite: Guest?
    @State private var invitePartySize: Int = 1
    @State private var invitePhoneNumber: String = ""
    @State private var inviteCode: String = ""
    @State private var showStatusBreakdown: Bool = false
    
    var filteredGuests: [Guest] {
        var result = guests
        if let filter = filter {
            result = result.filter { $0.rsvpStatus == filter }
        }
        if !searchText.isEmpty {
            result = result.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
        return result
    }
    
    var guestStats: GuestStats {
        let total = guests.count
        let attending = guests.filter { $0.rsvpStatus == .attending }.count
        let pending = guests.filter { $0.rsvpStatus == .noResponse }.count
        let totalPartySize = guests.reduce(0) { $0 + $1.partySize }
        let attendingPartySize = guests.filter { $0.rsvpStatus == .attending }.reduce(0) { $0 + $1.partySize }
        return GuestStats(total: total, attending: attending, pending: pending, totalPartySize: totalPartySize, attendingPartySize: attendingPartySize)
    }
    
    var checkedInCount: Int {
        guests.filter { $0.isCheckedIn }.count
    }
    
    var mealPreferences: [String: Int] {
        var meals: [String: Int] = [:]
        for guest in guests where guest.rsvpStatus == .attending {
            let meal = guest.mealChoice ?? "Not specified"
            meals[meal, default: 0] += guest.partySize
        }
        return meals
    }
    
    private var mealSummarySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "fork.knife")
                    .foregroundColor(.pink)
                Text("Meal Preferences")
                    .font(.headline)
                Spacer()
                Text("\(guestStats.attendingPartySize) guests")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal)
            
            if !mealPreferences.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(mealPreferences.sorted(by: { $0.value > $1.value }), id: \.key) { meal, count in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(meal)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Text("\(count)")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.pink)
                                Text("guests")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            .padding()
                            .background(Color(.systemBackground))
                            .cornerRadius(12)
                        }
                    }
                    .padding(.horizontal)
                }
            } else {
                Text("No meal preferences recorded yet")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
            }
        }
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack {
                    HStack(spacing: 20) {
                        StatBox(title: "Total", value: "\(guestStats.total)", color: .blue)
                        StatBox(title: "Party", value: "\(guestStats.totalPartySize)", color: .purple)
                    }
                    Image("RingSmall")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 40, height: 40)
                        .opacity(0.6)
                }
                .padding()

                DisclosureGroup(isExpanded: $showStatusBreakdown) {
                    HStack(spacing: 12) {
                        StatBox(title: "Attending", value: "\(guestStats.attending)", color: .green)
                        StatBox(title: "Pending", value: "\(guestStats.pending)", color: .orange)
                        StatBox(title: "Checked In", value: "\(checkedInCount)", color: .pink)
                    }
                    .padding(.top, 8)
                } label: {
                    Text("Show RSVP & check-in breakdown")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
                
                Picker("Filter", selection: $filter) {
                    Text("All").tag(RSVPStatus?.none)
                    Text("Attending").tag(RSVPStatus?.some(.attending))
                    Text("Declined").tag(RSVPStatus?.some(.declined))
                    Text("No Response").tag(RSVPStatus?.some(.noResponse))
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.horizontal)
                
                if guestStats.attending > 0 {
                    mealSummarySection
                }
                
                if filteredGuests.isEmpty {
                    if searchText.isEmpty && filter == nil {
                        ContentUnavailableView {
                            Label("No Guests Yet", systemImage: "person.3")
                        } description: {
                            Text("Add your first guest to start building your wedding list.")
                        } actions: {
                            Button("Add Guest") {
                                showingAddGuest = true
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.pink)
                        }
                    } else if !searchText.isEmpty {
                        ContentUnavailableView.search
                    } else {
                        ContentUnavailableView("No Guests Found", systemImage: "person.crop.circle.badge.questionmark", description: Text("Try changing your filter."))
                    }
                } else {
                    List {
                        ForEach(filteredGuests, id: \.id) { guest in
                            GuestRowView(
                                guest: guest,
                                onGenerateCode: { guest in
                                    self.guestForInvite = guest
                                    self.invitePartySize = guest.partySize
                                    self.invitePhoneNumber = guest.phone ?? ""
                                    self.inviteCode = guest.invitationCode ?? self.generateNewInviteCode()
                                    self.showingInviteSheet = true
                                },
                                onToggleCheckIn: { guest in
                                    toggleCheckIn(for: guest)
                                }
                            )
                        }
                        .onDelete(perform: deleteGuests)
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Guests")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button(action: { showingAddGuest = true }) {
                            Label("Add Guest", systemImage: "person.badge.plus")
                        }
                        if guestStats.pending > 0 {
                            Button(action: { sendRSVPReminders() }) {
                                Label("Remind \(guestStats.pending) Guests", systemImage: "bell.fill")
                            }
                        }
                        Button(action: { exportGuestList() }) {
                            Label("Export Guest List", systemImage: "square.and.arrow.up")
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingInviteSheet) {
                if let guest = guestForInvite {
                    InviteSetupSheet(
                        guestName: guest.name,
                        invitationCode: inviteCode,
                        weddingDetails: appState.weddingDetails,
                        partySize: $invitePartySize,
                        phoneNumber: $invitePhoneNumber,
                        onSend: {
                            self.generateInvitationCode(for: guest, partySize: invitePartySize, phoneNumber: invitePhoneNumber)
                            self.showingInviteSheet = false
                        }
                    )
                }
            }
            .sheet(isPresented: $showingAddGuest) {
                AddGuestView { newGuest in
                    var guestWithCode = newGuest
                    let newCode = generateNewInviteCode()
                    guestWithCode.invitationCode = newCode
                    
                    guests.append(guestWithCode)
                    saveGuests()
                    
                    let newInvitation = InvitationCode(
                        code: newCode,
                        weddingId: appState.weddingId ?? UUID(),
                        coupleNames: appState.weddingDetails.coupleNames,
                        date: appState.weddingDetails.date,
                        location: appState.weddingDetails.location,
                        guestId: guestWithCode.id,
                        guestName: guestWithCode.name,
                        partySize: guestWithCode.partySize,
                        phoneNumber: guestWithCode.phone
                    )
                    
                    var currentCodes = loadInvitationCodes() ?? []
                    currentCodes.append(newInvitation)
                    saveInvitationCodes(currentCodes)
                    
                    Task {
                        do {
                            try await appState.saveInvitationCodeToCloud(newInvitation)
                            try await appState.saveGuestToCloud(guestWithCode)
                        } catch {
                            print("Failed to sync new guest/code to CloudKit: \(error)")
                        }
                    }
                }
            }
            .onAppear {
                loadGuests()
            }
        }
    }
    
    private func generateNewInviteCode() -> String {
        let existingCodes = Set((loadInvitationCodes() ?? []).map(\.code))
        var code = InvitationCode.makeCode()
        while existingCodes.contains(code) {
            code = InvitationCode.makeCode()
        }
        return code
    }
    
    private func generateInvitationCode(for guest: Guest, partySize: Int, phoneNumber: String) {
        let code = inviteCode.isEmpty ? generateNewInviteCode() : inviteCode
        let weddingId = appState.weddingId ?? UUID()
        if appState.weddingId == nil {
            appState.weddingId = weddingId
        }
        
        var updatedGuest = guest
        updatedGuest.invitationCode = code
        updatedGuest.partySize = partySize
        if !phoneNumber.isEmpty {
            updatedGuest.phone = phoneNumber
        }
        
        if let index = guests.firstIndex(where: { $0.id == guest.id }) {
            guests[index] = updatedGuest
        } else {
            guests.append(updatedGuest)
        }
        saveGuests()
        
        var invitationCodes = loadInvitationCodes() ?? []
        let existingInvitation = invitationCodes.first(where: { $0.guestId == guest.id || $0.code == code })
        var invitation = InvitationCode(
            code: code,
            weddingId: weddingId,
            coupleNames: appState.weddingDetails.coupleNames,
            date: appState.weddingDetails.date,
            location: appState.weddingDetails.location,
            guestId: guest.id,
            guestName: guest.name,
            partySize: partySize,
            phoneNumber: phoneNumber.isEmpty ? nil : phoneNumber
        )
        invitation.rsvpStatus = existingInvitation?.rsvpStatus
        invitation.mealChoice = existingInvitation?.mealChoice
        invitation.dietaryNotes = existingInvitation?.dietaryNotes
        
        if let index = invitationCodes.firstIndex(where: { $0.guestId == guest.id || $0.code == code }) {
            invitationCodes[index] = invitation
        } else {
            invitationCodes.append(invitation)
        }
        saveInvitationCodes(invitationCodes)
        
        Task {
            do {
                try await appState.saveInvitationCodeToCloud(invitation)
                try await appState.saveGuestToCloud(updatedGuest)
            } catch {
                print("Failed to sync generated invitation code to CloudKit: \(error)")
            }
        }
    }
    
    private func loadGuests() {
        var loadedGuests = DataStore.shared.load([Guest].self, from: "guests.json") ?? []
        let invitationCodes = loadInvitationCodes() ?? []
        
        for index in loadedGuests.indices {
            guard let invitation = invitationCodes.first(where: {
                if let guestId = $0.guestId {
                    return guestId == loadedGuests[index].id
                }
                return $0.guestName?.caseInsensitiveCompare(loadedGuests[index].name) == .orderedSame
            }) else {
                continue
            }
            
            if loadedGuests[index].invitationCode == nil || loadedGuests[index].invitationCode?.isEmpty == true {
                loadedGuests[index].invitationCode = invitation.code
            }
            if (loadedGuests[index].phone == nil || loadedGuests[index].phone?.isEmpty == true),
               let phoneNumber = invitation.phoneNumber,
               !phoneNumber.isEmpty {
                loadedGuests[index].phone = phoneNumber
            }
            if loadedGuests[index].partySize == 1, invitation.partySize > 1 {
                loadedGuests[index].partySize = invitation.partySize
            }
            if let rsvpStatus = invitation.rsvpStatus {
                loadedGuests[index].rsvpStatus = rsvpStatus
            }
            if let mealChoice = invitation.mealChoice, loadedGuests[index].mealChoice == nil {
                loadedGuests[index].mealChoice = mealChoice
            }
            if let dietaryNotes = invitation.dietaryNotes, loadedGuests[index].dietaryNotes == nil {
                loadedGuests[index].dietaryNotes = dietaryNotes
            }
        }
        
        guests = loadedGuests
    }
    
    private func saveGuests() {
        _ = DataStore.shared.save(guests, to: "guests.json")
    }
    
    private func deleteGuests(at offsets: IndexSet) {
        let removedGuestIDs = offsets.map { guests[$0].id }
        guests.remove(atOffsets: offsets)
        saveGuests()
        
        var invitationCodes = loadInvitationCodes() ?? []
        invitationCodes.removeAll { invitation in
            guard let guestId = invitation.guestId else { return false }
            return removedGuestIDs.contains(guestId)
        }
        saveInvitationCodes(invitationCodes)
    }
    
    private func loadInvitationCodes() -> [InvitationCode]? {
        return DataStore.shared.load([InvitationCode].self, from: "invitation_codes.json")
    }
    
    private func saveInvitationCodes(_ codes: [InvitationCode]) {
        _ = DataStore.shared.save(codes, to: "invitation_codes.json")
    }
    
    private func sendRSVPReminders() {
        let pendingGuests = guests.filter { $0.rsvpStatus == .noResponse && ($0.phone != nil || $0.email != nil) }
        
        for guest in pendingGuests {
            if let phone = guest.phone, !phone.isEmpty {
                let coupleNames = appState.weddingDetails.coupleNames.isEmpty ? "Our Wedding" : appState.weddingDetails.coupleNames
                let dateFormatter = DateFormatter()
                dateFormatter.dateStyle = .long
                let dateStr = dateFormatter.string(from: appState.weddingDetails.date)
                
                let reminderMessage = """
                Hi \(guest.name)! Just a friendly reminder to RSVP for \(coupleNames) on \(dateStr). We can't wait to celebrate with you!
                
                RSVP link: vowplanner://rsvp
                """
                
                let smsUrl = "sms:\(phone)?body=\(reminderMessage.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
                if let url = URL(string: smsUrl) {
                    UIApplication.shared.open(url)
                    break
                }
            }
        }
    }
    
    private func exportGuestList() {
        let csvContent = guests.generateCSV()
        
        let activityVC = UIActivityViewController(activityItems: [csvContent], applicationActivities: nil)
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            rootVC.present(activityVC, animated: true)
        }
    }
    
    private func toggleCheckIn(for guest: Guest) {
        guard guest.rsvpStatus == .attending else { return }
        
        let shouldCheckIn = !guest.isCheckedIn
        if let index = guests.firstIndex(where: { $0.id == guest.id }) {
            guests[index].checkedInAt = shouldCheckIn ? Date() : nil
        }
        saveGuests()
        appState.setGuestCheckIn(for: guest.id, checkedIn: shouldCheckIn)
    }
}

struct StatBox: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }
}

struct GuestRowView: View {
    let guest: Guest
    let onGenerateCode: (Guest) -> Void
    let onToggleCheckIn: (Guest) -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(guest.name)
                    .font(.headline)
                if let household = guest.household, !household.isEmpty {
                    Text(household)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                // Show invitation code if available
                if let code = guest.invitationCode, !code.isEmpty {
                    Text("Code: \(code)")
                        .font(.caption)
                        .foregroundColor(.pink)
                }
                if let checkedInAt = guest.checkedInAt {
                    Text("Checked In: \(checkedInAt.formatted(date: .omitted, time: .shortened))")
                        .font(.caption)
                        .foregroundColor(.green)
                }
            }
            
            Spacer()
            
            RSVPBadge(status: guest.rsvpStatus)
            
            if guest.rsvpStatus == .attending {
                Button(action: {
                    onToggleCheckIn(guest)
                }) {
                    Image(systemName: guest.isCheckedIn ? "checkmark.circle.fill" : "checkmark.circle")
                        .font(.caption)
                        .padding(6)
                        .background(Color.green.opacity(0.15))
                        .foregroundColor(.green)
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
            
            // Generate code button
            Button(action: {
                onGenerateCode(guest)
            }) {
                Image(systemName: "qrcode")
                    .font(.caption)
                    .padding(6)
                    .background(Color.pink.opacity(0.2))
                    .cornerRadius(8)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }
}

struct RSVPBadge: View {
    let status: RSVPStatus
    
    var body: some View {
        Text(statusText)
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(statusColor.opacity(0.2))
            .foregroundColor(statusColor)
            .cornerRadius(12)
    }
    
    var statusText: String {
        switch status {
        case .attending: return "Attending"
        case .declined: return "Declined"
        case .noResponse: return "Pending"
        }
    }
    
    var statusColor: Color {
        switch status {
        case .attending: return .green
        case .declined: return .red
        case .noResponse: return .orange
        }
    }
}

struct AddGuestView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var email = ""
    @State private var phone = ""
    @State private var side: GuestSide = .both
    @State private var household = ""
    @State private var partySize = 1
    @State private var mealChoice = ""
    @State private var dietaryNotes = ""
    let onSave: (Guest) -> Void
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Guest Information") {
                    TextField("Name", text: $name)
                    TextField("Email (optional)", text: $email)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                    TextField("Phone (optional)", text: $phone)
                        .keyboardType(.phonePad)
                }
                
                Section("Side") {
                    Picker("Side", selection: $side) {
                        Text("Partner One").tag(GuestSide.partnerOne)
                        Text("Partner Two").tag(GuestSide.partnerTwo)
                        Text("Both").tag(GuestSide.both)
                    }
                    .pickerStyle(.segmented)
                }
                
                Section("Party Details") {
                    Stepper("Party Size: \(partySize)", value: $partySize, in: 1...10)
                    Text("Number of people in this party")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Section("Meal Preferences") {
                    TextField("Meal Choice (optional)", text: $mealChoice)
                        .textInputAutocapitalization(.words)
                    TextField("Dietary Notes (optional)", text: $dietaryNotes)
                        .textInputAutocapitalization(.sentences)
                }
                
                Section("Household (optional)") {
                    TextField("Household name", text: $household)
                }
            }
            .navigationTitle("Add Guest")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let guest = Guest(
                            name: name,
                            email: email.isEmpty ? nil : email,
                            phone: phone.isEmpty ? nil : phone,
                            side: side,
                            mealChoice: mealChoice.isEmpty ? nil : mealChoice,
                            dietaryNotes: dietaryNotes.isEmpty ? nil : dietaryNotes,
                            household: household.isEmpty ? nil : household,
                            partySize: partySize
                        )
                        onSave(guest)
                        dismiss()
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
    }
}

struct GuestDetailView: View {
    @State var guest: Guest
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var guests: [Guest] = []
    
    var body: some View {
        Form {
            Section("Information") {
                TextField("Name", text: $guest.name)
                TextField("Email", text: Binding($guest.email, default: ""))
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                TextField("Phone", text: Binding($guest.phone, default: ""))
                    .keyboardType(.phonePad)
            }
            
            Section("RSVP") {
                Picker("Status", selection: $guest.rsvpStatus) {
                    Text("Attending").tag(RSVPStatus.attending)
                    Text("Declined").tag(RSVPStatus.declined)
                    Text("No Response").tag(RSVPStatus.noResponse)
                }
                .pickerStyle(.segmented)
            }
            
            Section("Party Details") {
                Stepper("Party Size: \(guest.partySize)", value: $guest.partySize, in: 1...10)
                Text("Number of people in this party")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Section("Meal") {
                TextField("Meal Choice", text: Binding($guest.mealChoice, default: ""))
                TextField("Dietary Notes", text: Binding($guest.dietaryNotes, default: ""))
            }
            
            Section("Household") {
                TextField("Household", text: Binding($guest.household, default: ""))
            }
            
            Section("Check-In") {
                Toggle(
                    "Checked In",
                    isOn: Binding(
                        get: { guest.isCheckedIn },
                        set: { isCheckedIn in
                            guest.checkedInAt = isCheckedIn ? (guest.checkedInAt ?? Date()) : nil
                        }
                    )
                )
                if let checkedInAt = guest.checkedInAt {
                    Text("Checked in at \(checkedInAt.formatted(date: .omitted, time: .shortened))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Section("Side") {
                Picker("Side", selection: $guest.side) {
                    Text("Partner One").tag(GuestSide.partnerOne)
                    Text("Partner Two").tag(GuestSide.partnerTwo)
                    Text("Both").tag(GuestSide.both)
                }
            }
        }
        .navigationTitle("Guest Details")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            guests = DataStore.shared.load([Guest].self, from: "guests.json") ?? []
        }
        .onChange(of: guest) { _, _ in
            saveGuest()
        }
    }
    
    private func saveGuest() {
        if let index = guests.firstIndex(where: { $0.id == guest.id }) {
            guests[index] = guest
        } else {
            guests.append(guest)
        }
        _ = DataStore.shared.save(guests, to: "guests.json")
        Task {
            do {
                try await appState.saveGuestToCloud(guest)
            } catch {
                print("Failed to sync guest details to CloudKit: \(error)")
            }
        }
    }
}

struct GuestStatsChart: View {
    var guestStats: GuestStats
    
    var body: some View {
        HStack {
            if guestStats.total > 0 {
                Chart {
                    SectorMark(
                        angle: .value("Attending", guestStats.attending),
                        innerRadius: .ratio(0.6),
                        angularInset: 1.5
                    )
                    .cornerRadius(4)
                    .foregroundStyle(Color.green)
                    
                    SectorMark(
                        angle: .value("Pending", guestStats.pending),
                        innerRadius: .ratio(0.6),
                        angularInset: 1.5
                    )
                    .cornerRadius(4)
                    .foregroundStyle(Color.orange)
                    
                    SectorMark(
                        angle: .value("Declined", guestStats.total - guestStats.attending - guestStats.pending),
                        innerRadius: .ratio(0.6),
                        angularInset: 1.5
                    )
                    .cornerRadius(4)
                    .foregroundStyle(Color.red)
                }
                .frame(width: 80, height: 80)
                .padding(.trailing, 16)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Circle().fill(Color.green).frame(width: 8, height: 8)
                    Text("Attending: \(guestStats.attending)")
                        .font(.caption)
                }
                HStack {
                    Circle().fill(Color.orange).frame(width: 8, height: 8)
                    Text("Pending: \(guestStats.pending)")
                        .font(.caption)
                }
                HStack {
                    Circle().fill(Color.red).frame(width: 8, height: 8)
                    Text("Declined: \(guestStats.total - guestStats.attending - guestStats.pending)")
                        .font(.caption)
                }
            }
            Spacer()
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
}

struct InviteSetupSheet: View {
    let guestName: String
    let invitationCode: String
    let weddingDetails: WeddingDetails
    @Binding var partySize: Int
    @Binding var phoneNumber: String
    var onSend: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var showingShareSheet = false
    
    private var inviteMessage: String {
        let coupleNames = weddingDetails.coupleNames.isEmpty ? "Our Wedding" : weddingDetails.coupleNames
        let dateStr = formatDate(weddingDetails.date)
        let location = weddingDetails.location.isEmpty ? "" : "at \(weddingDetails.location)"
        return """
        You're invited to \(coupleNames)'s Wedding!
        
        📅 \(dateStr) \(location)
        
        Please RSVP using your unique code: \(invitationCode)
        
        RSVP here: vowplanner://rsvp/\(invitationCode)
        
        We can't wait to celebrate with you!
        """
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        return formatter.string(from: date)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Guest") {
                    Text(guestName)
                        .font(.headline)
                }
                
                Section("Party Size") {
                    Stepper("Party Size: \(partySize)", value: $partySize, in: 1...10)
                    Text("Number of people in this party")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Section("Invitation Code") {
                    HStack {
                        Text(invitationCode)
                            .font(.system(.title2, design: .monospaced))
                            .fontWeight(.bold)
                            .foregroundColor(.pink)
                        Spacer()
                        Button(action: {
                            UIPasteboard.general.string = invitationCode
                        }) {
                            Image(systemName: "doc.on.doc")
                        }
                    }
                    Text("Share this code with the guest")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Section("Send Invite") {
                    Button(action: { showingShareSheet = true }) {
                        HStack {
                            Image(systemName: "square.and.arrow.up")
                            Text("Share Invite")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    
                    if !phoneNumber.isEmpty {
                        Button(action: {
                            let smsUrl = "sms:\(phoneNumber)?body=\(inviteMessage.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
                            if let url = URL(string: smsUrl) {
                                UIApplication.shared.open(url)
                            }
                        }) {
                            HStack {
                                Image(systemName: "message.fill")
                                Text("Send via Text Message")
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                    
                    TextField("Phone Number (optional)", text: $phoneNumber)
                        .keyboardType(.phonePad)
                    Text("Add phone to send invite directly via text")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Send Invite")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingShareSheet) {
                ShareSheet(items: [inviteMessage])
            }
        }
    }
}
