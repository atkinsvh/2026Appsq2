import SwiftUI
import Charts

struct DashboardView: View {
    @EnvironmentObject var appState: AppState
    
    @State private var guests: [Guest] = []
    @State private var categories: [BudgetCategory] = []
    @State private var timelineItems: [TimelineItem] = []
    @State private var vendors: [Vendor] = []
    
    @State private var showingAddGuest = false
    @State private var showingAddExpense = false
    @State private var showingAddVendor = false
    @State private var selectedCategoryForExpense: BudgetCategory?
    @State private var showingNoBudgetAlert = false
    @State private var expenseAmount = ""
    @State private var expenseNote = ""
    
    var guestStats: GuestStats {
        let total = guests.count
        let attending = guests.filter { $0.rsvpStatus == .attending }.count
        let pending = guests.filter { $0.rsvpStatus == .noResponse }.count
        let totalPartySize = guests.reduce(0) { $0 + $1.partySize }
        let attendingPartySize = guests.filter { $0.rsvpStatus == .attending }.reduce(0) { $0 + $1.partySize }
        return GuestStats(total: total, attending: attending, pending: pending, totalPartySize: totalPartySize, attendingPartySize: attendingPartySize)
    }
    
    var budgetSummary: BudgetSummary {
        let planned = categories.reduce(0) { $0 + $1.allocated }
        let spent = categories.reduce(0) { $0 + $1.spent }
        return BudgetSummary(planned: planned, spent: spent)
    }
    
    var upcomingTasks: [TimelineItem] {
        timelineItems.filter { !$0.completed }
            .sorted { $0.dueDate < $1.dueDate }
            .prefix(3)
            .map { $0 }
    }
    
    private var emptyGuestsCard: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.3")
                .font(.system(size: 40))
                .foregroundColor(.blue.opacity(0.6))
            
            Text("No Guests Yet")
                .font(.headline)
            
            Text("Start building your guest list")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Button(action: { showingAddGuest = true }) {
                Label("Add Guest", systemImage: "person.badge.plus")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.blue)
        }
        .padding(24)
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Warm welcome message
                    welcomeMessage
                    
                    weddingInfoCard
                    
                    if guestStats.total > 0 {
                        GuestStatsChart(guestStats: guestStats)
                    } else {
                        emptyGuestsCard
                    }
                    
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        DashboardStatCard(
                            title: "Guests",
                            value: "\(guestStats.total)",
                            subtitle: "\(guestStats.attending) attending",
                            icon: "person.3.fill",
                            color: .blue
                        )
                        
                        DashboardStatCard(
                            title: "Budget",
                            value: "$\(Int(budgetSummary.spent))",
                            subtitle: "of $\(Int(budgetSummary.planned))",
                            icon: "dollarsign.circle.fill",
                            color: .green
                        )
                        
                        DashboardStatCard(
                            title: "Vendors",
                            value: "\(vendors.count)",
                            subtitle: "booked",
                            icon: "bag.fill",
                            color: .purple
                        )
                        
                        DashboardStatCard(
                            title: "Timeline",
                            value: "\(timelineItems.filter { $0.completed }.count)",
                            subtitle: "of \(timelineItems.count) tasks",
                            icon: "checklist.checked",
                            color: .orange
                        )
                    }
                    
                    upcomingTasksSection
                    
                    quickActionsSection
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Dashboard")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button(action: { showingAddGuest = true }) {
                            Label("Add Guest", systemImage: "person.badge.plus")
                        }
                        Button(action: {
                            if let firstCategory = categories.first {
                                selectedCategoryForExpense = firstCategory
                                showingAddExpense = true
                            } else {
                                showingNoBudgetAlert = true
                            }
                        }) {
                            Label("Track Expense", systemImage: "creditcard")
                        }
                        Button(action: { showingAddVendor = true }) {
                            Label("Add Vendor", systemImage: "bag.badge.plus")
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddGuest) {
                AddGuestView { newGuest in
                    guests.append(newGuest)
                    saveGuests()
                    Task {
                        do {
                            try await appState.saveGuestToCloud(newGuest)
                        } catch {
                            print("Failed to sync guest from dashboard: \(error)")
                        }
                    }
                }
            }
            .sheet(isPresented: $showingAddExpense) {
                NavigationStack {
                    Form {
                        Section("Expense Details") {
                            TextField("Amount", text: $expenseAmount)
                                .keyboardType(.decimalPad)
                            TextField("Note (optional)", text: $expenseNote)
                        }
                    }
                    .navigationTitle("Add Expense")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") {
                                expenseAmount = ""
                                expenseNote = ""
                                showingAddExpense = false
                            }
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Save") {
                                saveExpense()
                            }
                            .disabled(expenseAmount.isEmpty)
                        }
                    }
                }
            }
            .sheet(isPresented: $showingAddVendor) {
                AddVendorView { newVendor in
                    vendors.append(newVendor)
                    saveVendors()
                    Task {
                        do {
                            try await appState.saveVendorsToCloud(vendors)
                        } catch {
                            print("Failed to sync vendors from dashboard: \(error)")
                        }
                    }
                }
            }
            .alert("No Budget Categories", isPresented: $showingNoBudgetAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Please add a budget category first.")
            }
            .onAppear {
                loadGuests()
                loadBudget()
                loadTimeline()
                loadVendors()
            }
        }
    }
    
    private var welcomeMessage: some View {
        VStack(spacing: 4) {
            if appState.weddingDetails.coupleNames.isEmpty {
                Text("Welcome to your wedding journey! 💕")
                    .font(.headline)
                    .foregroundColor(.pink)
            } else {
                Text("Welcome back, \(appState.weddingDetails.coupleNames)!")
                    .font(.headline)
                    .foregroundColor(.pink)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .padding(.horizontal)
        .background(Color.pink.opacity(0.1))
        .cornerRadius(12)
    }
    
    private var weddingInfoCard: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(appState.weddingDetails.coupleNames.isEmpty ? "Your Wedding" : appState.weddingDetails.coupleNames)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    if appState.weddingDetails.date > Date() {
                        Text(weddingDateText)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
                Image(systemName: "heart.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 44, height: 44)
                    .foregroundColor(.pink)
            }
            
            if !appState.weddingDetails.location.isEmpty {
                HStack {
                    Image(systemName: "mappin.circle.fill")
                        .foregroundColor(.secondary)
                    Text(appState.weddingDetails.location)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                }
            }
            
            if appState.weddingDetails.date > Date() {
                let days = Calendar.current.dateComponents([.day], from: Date(), to: appState.weddingDetails.date).day ?? 0
                HStack {
                    Text("\(days) days to go!")
                        .font(.subheadline)
                        .foregroundColor(.pink)
                    Spacer()
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
    
    private var upcomingTasksSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Upcoming Tasks")
                    .font(.headline)
                Spacer()
                Text("\(upcomingTasks.count)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal)
            
            ForEach(upcomingTasks) { item in
                HStack(spacing: 12) {
                    Image(systemName: item.completed ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(item.completed ? .green : .secondary)
                        .font(.title3)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.title)
                            .font(.body)
                        Text(item.dueDate, style: .date)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color(.systemBackground))
                .cornerRadius(8)
            }
        }
        .padding(.vertical, 8)
    }
    
    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Actions")
                .font(.headline)
                .padding(.horizontal)
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                QuickActionRow(
                    icon: "person.badge.plus",
                    title: "Add Guest",
                    color: .blue,
                    action: { showingAddGuest = true }
                )
                
                QuickActionRow(
                    icon: "creditcard",
                    title: "Track Expense",
                    color: .green,
                    action: {
                        if let firstCategory = categories.first {
                            selectedCategoryForExpense = firstCategory
                            showingAddExpense = true
                        } else {
                            showingNoBudgetAlert = true
                        }
                    }
                )
                
                QuickActionRow(
                    icon: "bag.badge.plus",
                    title: "Add Vendor",
                    color: .purple,
                    action: { showingAddVendor = true }
                )
                
                QuickActionRow(
                    icon: "globe",
                    title: "Website",
                    color: .orange,
                    action: {
                        // Navigate to website tab
                        appState.tooltipsDismissed.insert("website")
                    }
                )
            }
        }
        .padding(.vertical, 8)
    }
    
    private var weddingDateText: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        return formatter.string(from: appState.weddingDetails.date)
    }
    
    private func loadGuests() {
        guests = appState.dataStore.load([Guest].self, from: "guests.json") ?? []
    }
    
    private func saveGuests() {
        _ = appState.dataStore.save(guests, to: "guests.json")
    }
    
    private func loadBudget() {
        if let savedCategories = appState.dataStore.load([BudgetCategory].self, from: "budget_categories.json") {
            categories = savedCategories
        } else {
            categories = appState.dataStore.load([BudgetCategory].self, from: "budget.json") ?? []
            if !categories.isEmpty {
                _ = appState.dataStore.save(categories, to: "budget_categories.json")
            }
        }
    }
    
    private func loadTimeline() {
        timelineItems = appState.dataStore.load([TimelineItem].self, from: "timeline.json") ?? []
    }
    
    private func loadVendors() {
        vendors = appState.dataStore.load([Vendor].self, from: "vendors.json") ?? []
    }
    
    private func saveVendors() {
        _ = appState.dataStore.save(vendors, to: "vendors.json")
    }
    
    private func saveExpense() {
        if let categoryIndex = categories.firstIndex(where: { $0.id == selectedCategoryForExpense?.id }),
           let amount = Double(expenseAmount) {
            categories[categoryIndex].spent += amount
            _ = appState.dataStore.save(categories, to: "budget_categories.json")
            Task {
                do {
                    try await appState.saveBudgetToCloud(categories)
                } catch {
                    print("Failed to sync budget from dashboard: \(error)")
                }
            }
            expenseAmount = ""
            expenseNote = ""
        }
    }
}

struct DashboardStatCard: View {
    let title: String
    let value: String
    let subtitle: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.title3)
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
            }
            
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
            
            Text(subtitle)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 12)
        .padding(.horizontal)
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
}

struct QuickActionRow: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .frame(width: 44, height: 44)
                    .background(color.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                
                Text(title)
                    .font(.body)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 12)
            .padding(.horizontal)
            .padding(.horizontal)
        }
        .buttonStyle(.plain)
    }
}
