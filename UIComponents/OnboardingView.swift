import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

enum OnboardingStep: Int, CaseIterable {
    case welcome = 0
    case roleSelection = 1
    case weddingDetails = 2
    case budgetDetails = 3
    case invitePartner = 4
    case todoList = 5
}

struct OnboardingView: View {
    @EnvironmentObject var appState: AppState
    @State private var currentStep: OnboardingStep = .welcome
    @State private var userRole: UserRole = .host
    @State private var coupleNames: String = ""
    @State private var weddingDate: Date = Date().addingTimeInterval(365 * 24 * 60 * 60)
    @State private var weddingLocation: String = ""
    @State private var guestCount: String = "50"
    @State private var budgetAmount: String = "15000"
    @State private var invitationCode: String = ""
    @State private var coPlannerCode: String = ""
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showCopiedToast = false
    
    enum UserRole: String, CaseIterable {
        case host = "Planning a Wedding"
        case guest = "I've Been Invited"
        case coplanner = "Join as Co-Planner"
        
        var icon: String {
            switch self {
            case .host: return "heart.circle.fill"
            case .guest: return "envelope.fill"
            case .coplanner: return "person.2.fill"
            }
        }
        
        var description: String {
            switch self {
            case .host: return "Start planning your special day"
            case .guest: return "RSVP to a wedding you're invited to"
            case .coplanner: return "Help plan an existing wedding"
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    progressIndicator
                        .padding(.top, 12)
                    
                    ScrollView {
                        VStack(spacing: 20) {
                            switch currentStep {
                            case .welcome:
                                welcomeStep
                            case .roleSelection:
                                roleSelectionStep
                            case .weddingDetails:
                                weddingDetailsStep
                            case .budgetDetails:
                                budgetDetailsStep
                            case .invitePartner:
                                if userRole == .host {
                                    invitePartnerStep
                                } else {
                                    guestCodeEntryStep
                                }
                            case .todoList:
                                todoListStep
                            }
                        }
                        .padding()
                    }
                }
                .safeAreaInset(edge: .bottom) {
                    Color.clear.frame(height: 0)
                }
            }
            .navigationTitle("")
            .navigationBarHidden(true)
            .alert("Something Went Wrong", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private var progressIndicator: some View {
        HStack(spacing: 8) {
            ForEach(0..<6) { index in
                Circle()
                    .fill(index <= currentStep.rawValue ? Color.pink : Color.gray.opacity(0.4))
                    .frame(width: 8, height: 8)
            }
        }
    }
    
    private var welcomeStep: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image("BrandLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 100, height: 100)
            
            VStack(spacing: 12) {
                Text("Welcome to VowPlanner")
                    .font(.title)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                
                Text("Love is for everyone. Let's plan your perfect day together.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Spacer()
            
            Button(action: { withAnimation { currentStep = .roleSelection }}) {
                Text("Get Started")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.pink)
                    .foregroundColor(.white)
                    .cornerRadius(14)
            }
            .padding(.horizontal, 24)
        }
    }
    
    private var roleSelectionStep: some View {
        VStack(spacing: 24) {
            Text("How are you using VowPlanner?")
                .font(.title2)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
            
            ForEach(UserRole.allCases, id: \.self) { role in
                Button(action: {
                    withAnimation {
                        userRole = role
                        if role == .host {
                            currentStep = .weddingDetails
                        } else if role == .guest {
                            // Guest: go to code entry step
                            currentStep = .invitePartner
                        } else if role == .coplanner {
                            // Co-planner: go to code entry step (will show different label)
                            currentStep = .invitePartner
                        }
                    }
                }) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(role.rawValue)
                                .font(.headline)
                                .foregroundColor(.primary)
                            Text(role.description)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Image(systemName: role.icon)
                            .font(.title)
                            .foregroundColor(.pink)
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(16)
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    private var weddingDetailsStep: some View {
        VStack(spacing: 24) {
            Text("Tell us about your wedding")
                .font(.title2)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Couple Names")
                    .font(.headline)
                TextField("e.g., Sarah & John", text: $coupleNames)
                    .textFieldStyle(.plain)
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Wedding Date")
                    .font(.headline)
                DatePicker("", selection: $weddingDate, displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Location")
                    .font(.headline)
                TextField("e.g., Sunset Beach Resort", text: $weddingLocation)
                    .textFieldStyle(.plain)
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Estimated Guest Count")
                    .font(.headline)
                TextField("50", text: $guestCount)
                    .keyboardType(.numberPad)
                    .textFieldStyle(.plain)
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
            }
            
            Spacer()
            
            Button(action: saveWeddingDetails) {
                Text("Continue")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(coupleNames.isEmpty ? Color.gray : Color.pink)
                    .foregroundColor(.white)
                    .cornerRadius(14)
            }
            .disabled(coupleNames.isEmpty)
        }
    }
    
    private var budgetDetailsStep: some View {
        VStack(spacing: 24) {
            Image("HeartLarge")
                .resizable()
                .scaledToFit()
                .frame(width: 80, height: 80)
            
            Text("Set Your Budget")
                .font(.title2)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
            
            Text("This will be your starting budget for wedding expenses")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Total Budget")
                    .font(.headline)
                HStack {
                    Text("$")
                        .font(.title2)
                        .foregroundColor(.secondary)
                    TextField("15000", text: $budgetAmount)
                        .font(.system(size: 32, weight: .bold))
                        .keyboardType(.decimalPad)
                        .padding()
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(12)
            }
            
            Spacer()
            
            Button(action: saveBudgetDetails) {
                Text("Continue")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(budgetAmount.isEmpty ? Color.gray : Color.pink)
                    .foregroundColor(.white)
                    .cornerRadius(14)
            }
            .disabled(budgetAmount.isEmpty)
        }
    }
    
    private var invitePartnerStep: some View {
        VStack(spacing: 24) {
            Image(systemName: "person.2.fill")
                .font(.system(size: 60))
                .foregroundColor(.pink)
            
            Text("Invite Your Co-Planner")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Share this code with your partner or co-planner to help manage the wedding")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            if coPlannerCode.isEmpty {
                ProgressView("Creating secure co-planner code...")
                    .padding()
            } else {
                VStack(spacing: 12) {
                    Text("Co-Planner Code")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(coPlannerCode)
                        .font(.system(size: 36, weight: .bold, design: .monospaced))
                        .foregroundColor(.pink)
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(12)
                        .onTapGesture {
                            copyCode(coPlannerCode)
                        }
                }
            }
            
            Button(action: { copyCode(coPlannerCode) }) {
                HStack {
                    Image(systemName: "doc.on.doc")
                    Text("Copy Code")
                }
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(.systemGray6))
                .foregroundColor(.primary)
                .cornerRadius(14)
            }
            .padding(.horizontal, 24)
            .disabled(coPlannerCode.isEmpty)
            
            Button(action: {
                withAnimation { currentStep = .todoList }
            }) {
                Text("Continue")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.pink)
                    .foregroundColor(.white)
                    .cornerRadius(14)
            }
            .padding(.horizontal, 24)
            .disabled(coPlannerCode.isEmpty)
            
            if showCopiedToast {
                Text("Code copied to clipboard!")
                    .font(.caption)
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.green)
                    .cornerRadius(8)
                .transition(.opacity)
            }
        }
    }
    
    // Guest code entry for RSVP / Co-planner code entry
    private var guestCodeEntryStep: some View {
        VStack(spacing: 24) {
            Image(systemName: userRole == .coplanner ? "person.2.fill" : "gift.fill")
                .font(.system(size: 60))
                .foregroundColor(.pink)
            
            Text(userRole == .coplanner ? "Join Wedding Planning" : "You're Invited!")
                .font(.title2)
                .fontWeight(.bold)
            
            Text(userRole == .coplanner ? 
                 "Enter your co-planner code to access the wedding" :
                 "Enter the invitation code to RSVP to the wedding")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            VStack(spacing: 12) {
                Text(userRole == .coplanner ? "Co-Planner Code" : "Invitation Code")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                TextField("ABC123", text: $invitationCode)
                    .font(.system(size: 36, weight: .bold, design: .monospaced))
                    .multilineTextAlignment(.center)
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .onChange(of: invitationCode) { _, newValue in
                        invitationCode = appState.normalizeInvitationCode(newValue)
                    }
            }
            
            Button(action: validateGuestCode) {
                Text("Continue")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(invitationCode.count == 6 ? Color.pink : Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(14)
            }
            .disabled(invitationCode.count != 6)
            .padding(.horizontal, 24)
        }
    }
    
    private func copyCode(_ code: String) {
        #if canImport(UIKit)
        UIPasteboard.general.string = code
        #endif
        withAnimation {
            showCopiedToast = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                showCopiedToast = false
            }
        }
    }
    
    private func saveCoPlannerCode() {
        guard !coPlannerCode.isEmpty else { return }
        let weddingId = appState.weddingId ?? UUID()
        if appState.weddingId == nil {
            appState.weddingId = weddingId
        }
        
        let codes = DataStore.shared.load([InvitationCode].self, from: "co_planner_codes.json") ?? []
        let newCode = InvitationCode(
            code: coPlannerCode,
            weddingId: weddingId,
            coupleNames: coupleNames,
            date: weddingDate,
            location: weddingLocation,
            guestId: nil,
            guestName: "Co-Planner"
        )
        var updatedCodes = codes
        if let index = updatedCodes.firstIndex(where: { $0.code == coPlannerCode || $0.weddingId == weddingId }) {
            updatedCodes[index] = newCode
        } else {
            updatedCodes.append(newCode)
        }
        _ = DataStore.shared.save(updatedCodes, to: "co_planner_codes.json")
    }
    
    private var todoListStep: some View {
        VStack(spacing: 20) {
            Text("Your Love Story Begins")
                .font(.title2)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
            
            Text("Love is for everyone, and everyone is for love. Here's your personalized checklist to help make your dream day come true.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            VStack(alignment: .leading, spacing: 12) {
                ForEach(generateTodoList(), id: \.self) { todo in
                    HStack(spacing: 12) {
                        Image(systemName: "circle")
                            .foregroundColor(.pink)
                        Text(todo)
                            .font(.body)
                    }
                    .padding(.vertical, 4)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .padding(.horizontal)
            
            Button(action: completeOnboarding) {
                Text("Get Started")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.pink)
                    .foregroundColor(.white)
                    .cornerRadius(14)
            }
            .padding(.horizontal, 24)
            
            if showCopiedToast {
                Text("Code copied to clipboard!")
                    .font(.caption)
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.green)
                    .cornerRadius(8)
                    .transition(.opacity)
            }
        }
    }
    
    private func saveWeddingDetails() {
        let weddingDetails = WeddingDetails(
            coupleNames: coupleNames,
            date: weddingDate,
            location: weddingLocation
        )
        appState.weddingDetails = weddingDetails
        _ = DataStore.shared.save(weddingDetails, to: "wedding_details.json")
        
        // Set weddingId SYNCHRONOUSLY before proceeding
        let weddingId = appState.weddingId ?? UUID()
        appState.weddingId = weddingId
        _ = appState.registerWeddingMembership(
            weddingId: weddingId,
            role: .host,
            details: weddingDetails
        )
        
        // Sync to CloudKit (async)
        Task {
            try? await appState.cloudKitSync.saveWedding(weddingDetails, weddingId: weddingId)
        }
        
        withAnimation { currentStep = .budgetDetails }
    }
    
    private func saveBudgetDetails() {
        let totalBudget = Double(budgetAmount) ?? 15000
        
        // Create default budget categories based on total budget
        let categories: [BudgetCategory] = [
            BudgetCategory(name: "Venue", allocated: totalBudget * 0.40),
            BudgetCategory(name: "Catering", allocated: totalBudget * 0.20),
            BudgetCategory(name: "Photography", allocated: totalBudget * 0.10),
            BudgetCategory(name: "Attire", allocated: totalBudget * 0.08),
            BudgetCategory(name: "Flowers & Decor", allocated: totalBudget * 0.06),
            BudgetCategory(name: "Music", allocated: totalBudget * 0.05),
            BudgetCategory(name: "Invitations", allocated: totalBudget * 0.03),
            BudgetCategory(name: "Cake", allocated: totalBudget * 0.02),
            BudgetCategory(name: "Transportation", allocated: totalBudget * 0.03),
            BudgetCategory(name: "Gifts", allocated: totalBudget * 0.03)
        ]
        
        _ = DataStore.shared.save(categories, to: "budget_categories.json")
        
        // Sync to CloudKit
        if let weddingId = appState.weddingId {
            Task {
                try? await appState.cloudKitSync.saveBudget(categories, weddingId: weddingId)
            }
        } else {
            print("Warning: No weddingId when saving budget to CloudKit")
        }
        
        // Go to invite partner step for hosts, or todo list for guests
        if userRole == .host {
            coPlannerCode = ""
            withAnimation { currentStep = .invitePartner }
            Task {
                do {
                    let generatedCode = try await appState.generateCoPlannerCode()
                    await MainActor.run {
                        coPlannerCode = generatedCode
                        saveCoPlannerCode()
                    }
                } catch {
                    await MainActor.run {
                        errorMessage = "Could not create a co-planner code right now. You can generate one later from your profile."
                        showError = true
                        withAnimation { currentStep = .todoList }
                    }
                }
            }
        } else {
            withAnimation { currentStep = .todoList }
        }
    }
    
    private func validateGuestCode() {
        let cleanCode = invitationCode.uppercased()
        guard cleanCode.count == 6 else {
            errorMessage = "Please enter a valid 6-character code"
            showError = true
            return
        }
        
        Task {
            if userRole == .coplanner {
                // Co-planner: validate via CloudKit
                do {
                    let success = try await appState.joinAsCoPlanner(with: cleanCode)
                    await MainActor.run {
                        if success {
                            appState.fetchWeddingsForCurrentUser()
                            withAnimation { currentStep = .todoList }
                        } else {
                            errorMessage = "Invalid co-planner code"
                            showError = true
                        }
                    }
                } catch {
                    await MainActor.run {
                        errorMessage = "Could not connect to CloudKit"
                        showError = true
                    }
                }
            } else {
                do {
                    let invitation = try await appState.verifyGuestInvitationCode(cleanCode)
                    await MainActor.run {
                        appState.enterGuestMode(with: invitation)
                    }
                } catch {
                    await MainActor.run {
                        errorMessage = error.localizedDescription
                        showError = true
                    }
                }
            }
        }
    }
    
    private func completeOnboarding() {
        appState.onboardingCompleted = true
        appState.isGuestMode = userRole == .guest
        // Save todo list
        let todos = generateTodoList()
        _ = DataStore.shared.save(todos, to: "todo_list.json")
    }
    
    private func generateTodoList() -> [String] {
        let calendar = Calendar.current
        let daysUntilWedding = calendar.dateComponents([.day], from: Date(), to: weddingDate).day ?? 365
        
        var todos: [String] = []
        
        if daysUntilWedding > 180 {
            todos.append("Book venue")
            todos.append("Set up budget categories")
            todos.append("Create guest list")
            todos.append("Book photographer")
        }
        
        if daysUntilWedding > 120 {
            todos.append("Choose wedding party")
            todos.append("Start dress/suit shopping")
            todos.append("Create wedding website")
        }
        
        if daysUntilWedding > 60 {
            todos.append("Send save the dates")
            todos.append("Book caterer")
            todos.append("Order invitations")
        }
        
        if daysUntilWedding > 30 {
            todos.append("Send invitations")
            todos.append("Finalize menu")
            todos.append("Plan seating chart")
        }
        
        return todos
    }
}

#Preview {
    OnboardingView()
        .environmentObject(AppState())
}

struct WeddingPhase: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let items: [String]
    let color: Color
    let icon: String
    
    static let samples: [WeddingPhase] = [
        WeddingPhase(title: "12+ Months Before", subtitle: "The Foundation", items: ["Book venue", "Set budget", "Guest list"], color: Color.pink.opacity(0.8), icon: "calendar.badge.plus"),
        WeddingPhase(title: "6-12 Months Before", subtitle: "Vendor Selection", items: ["Book vendors", "Find dress/suit", "Save the dates"], color: Color.purple.opacity(0.8), icon: "bag.fill"),
        WeddingPhase(title: "3-6 Months Before", subtitle: "The Details", items: ["Send invitations", "Registry", "Honeymoon"], color: Color.blue.opacity(0.8), icon: "envelope.fill"),
        WeddingPhase(title: "1-3 Months Before", subtitle: "Final Preparations", items: ["Fittings", "RSVPs", "Seating chart"], color: Color.orange.opacity(0.8), icon: "checkmark.circle.fill"),
        WeddingPhase(title: "The Wedding Day", subtitle: "Things No One Thinks About", items: ["Marriage license", "Vendor payments", "Emergency kit"], color: Color.red.opacity(0.8), icon: "heart.fill")
    ]
}

struct PhaseCard: View {
    let phase: WeddingPhase
    let isExpanded: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: phase.icon)
                    .font(.title2)
                    .foregroundColor(.white)
                    .frame(width: 40, height: 40)
                    .background(phase.color)
                    .cornerRadius(10)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(phase.title)
                        .font(.headline)
                    Text(phase.subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
    }
}

#Preview {
    OnboardingView()
        .environmentObject(AppState())
}
