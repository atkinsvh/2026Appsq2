import SwiftUI
import Charts

struct BudgetView: View {
    @State private var categories: [BudgetCategory] = []
    @State private var showingAddCategory = false
    @State private var showingAddExpense = false
    @State private var selectedCategory: BudgetCategory?
    @State private var showingEditBudget = false
    @State private var totalBudgetInput: String = ""
    @State private var showingAddCategoryAlert = false
    @State private var newCategoryName = ""
    @State private var newCategoryAmount = ""
    @State private var showingExpenseAlert = false
    @State private var expenseAmount = ""
    @State private var expenseNote = ""
    @EnvironmentObject var appState: AppState
    
    var totalBudget: Double {
        categories.reduce(0) { $0 + $1.allocated }
    }
    
    var totalSpent: Double {
        categories.reduce(0) { $0 + $1.spent }
    }
    
    var remaining: Double {
        totalBudget - totalSpent
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    budgetHeader
                        .padding(.horizontal)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Categories")
                                .font(.headline)
                            Spacer()
                            Button(action: { showingAddCategoryAlert = true }) {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundColor(.pink)
                            }
                        }
                        .padding(.horizontal)
                        
                        if categories.isEmpty {
                            ContentUnavailableView {
                                Label("No Budget Categories", systemImage: "dollarsign.circle")
                            } description: {
                                Text("Add your first category to start tracking your wedding budget.")
                            } actions: {
                                Button("Add Category") {
                                    showingAddCategoryAlert = true
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(.pink)
                            }
                            .padding(.top, 40)
                        } else {
                            ForEach(categories, id: \.id) { category in
                                Button(action: {
                                    selectedCategory = category
                                    showingExpenseAlert = true
                                }) {
                                    BudgetCategoryRow(category: category)
                                }
                                .buttonStyle(.plain)
                                .padding(.horizontal)
                            }
                        }
                    }
                }
                .padding(.vertical)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Budget")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button(action: { showingAddCategoryAlert = true }) {
                            Label("Add Category", systemImage: "plus.circle")
                        }
                        Button(action: { 
                            totalBudgetInput = String(format: "%.2f", totalBudget)
                            showingEditBudget = true 
                        }) {
                            Label("Edit Budget", systemImage: "pencil.circle")
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .alert("Add Category", isPresented: $showingAddCategoryAlert) {
                TextField("Category Name", text: $newCategoryName)
                TextField("Amount", text: $newCategoryAmount)
                Button("Add") {
                    if let amount = Double(newCategoryAmount), !newCategoryName.isEmpty {
                        categories.append(BudgetCategory(name: newCategoryName, allocated: amount))
                        saveCategories()
                        Haptics.shared.notify(.success)
                    }
                    newCategoryName = ""
                    newCategoryAmount = ""
                }
                Button("Cancel", role: .cancel) {
                    newCategoryName = ""
                    newCategoryAmount = ""
                }
            }
            .alert("Add Expense", isPresented: $showingExpenseAlert) {
                TextField("Amount", text: $expenseAmount)
                TextField("Note (optional)", text: $expenseNote)
                Button("Add") {
                    if let amount = Double(expenseAmount), let category = selectedCategory,
                       let index = categories.firstIndex(where: { $0.id == category.id }) {
                        categories[index].spent += amount
                        saveCategories()
                        Haptics.shared.notify(.success)
                    }
                    expenseAmount = ""
                    expenseNote = ""
                }
                Button("Cancel", role: .cancel) {
                    expenseAmount = ""
                    expenseNote = ""
                }
            } message: {
                if let category = selectedCategory {
                    Text("Add expense to \(category.name)")
                }
            }
            .sheet(isPresented: $showingEditBudget) {
                EditBudgetSheet(totalBudget: $totalBudgetInput) { newTotal in
                    let currentTotal = totalBudget
                    let difference = newTotal - currentTotal
                    if !categories.isEmpty {
                        let perCategory = difference / Double(categories.count)
                        for i in 0..<categories.count {
                            categories[i].allocated += perCategory
                        }
                    }
                    saveCategories()
                }
            }
            .onAppear {
                loadCategories()
            }
        }
    }
    
    private var budgetHeader: some View {
        VStack(spacing: 16) {
            VStack(spacing: 4) {
                Text("Total Budget")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Text("$\(totalBudget, specifier: "%.2f")")
                    .font(.system(size: 32, weight: .bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            
            if !categories.isEmpty && totalSpent > 0 {
                Chart(categories.filter { $0.spent > 0 }, id: \.id) { category in
                    SectorMark(
                        angle: .value("Spent", category.spent),
                        innerRadius: .ratio(0.6),
                        angularInset: 1.5
                    )
                    .cornerRadius(4)
                    .foregroundStyle(by: .value("Category", category.name))
                }
                .frame(height: 180)
                .chartLegend(position: .bottom, spacing: 10)
                .padding(.vertical, 8)
            } else {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 10)
                        
                        RoundedRectangle(cornerRadius: 6)
                            .fill(totalBudget > 0 ? Color.pink : Color.gray)
                            .frame(width: geometry.size.width * CGFloat(min(totalSpent / max(totalBudget, 1), 1.0)), height: 10)
                    }
                }
                .frame(height: 10)
                .padding(.vertical, 10)
            }
            
            HStack(spacing: 32) {
                VStack(spacing: 4) {
                    Text("Spent")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("$\(totalSpent, specifier: "%.2f")")
                        .font(.body)
                        .fontWeight(.semibold)
                        .foregroundColor(.orange)
                }
                
                VStack(spacing: 4) {
                    Text("Remaining")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("$\(remaining, specifier: "%.2f")")
                        .font(.body)
                        .fontWeight(.semibold)
                        .foregroundColor(remaining >= 0 ? .green : .red)
                }
            }
        }
        .padding(20)
        .background(
            LinearGradient(colors: [Color.pink.opacity(0.1), Color.purple.opacity(0.1)], startPoint: .topLeading, endPoint: .bottomTrailing)
        )
        .cornerRadius(20)
    }
    
    private func loadCategories() {
        let savedCategories = appState.loadBudgetFromStorage()
        if savedCategories.isEmpty {
            categories = defaultCategories()
        } else {
            categories = savedCategories
        }
    }
    
    private func saveCategories() {
        appState.saveBudgetToStorage(categories)
        Task {
            do {
                try await appState.saveBudgetToCloud(categories)
            } catch {
                print("Failed to save budget to cloud: \(error)")
            }
        }
    }
    
    private func defaultCategories() -> [BudgetCategory] {
        [
            BudgetCategory(name: "Venue", allocated: 10000),
            BudgetCategory(name: "Catering", allocated: 5000),
            BudgetCategory(name: "Photography", allocated: 3000),
            BudgetCategory(name: "Attire", allocated: 2500),
            BudgetCategory(name: "Flowers & Decor", allocated: 2000),
            BudgetCategory(name: "Music", allocated: 1500),
            BudgetCategory(name: "Invitations", allocated: 500),
            BudgetCategory(name: "Cake", allocated: 500)
        ]
    }
}

struct EditBudgetSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var totalBudget: String
    let onSave: (Double) -> Void
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 30) {
                VStack(spacing: 12) {
                    Text("Set Total Budget")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    HStack(alignment: .center, spacing: 8) {
                        Text("$")
                            .font(.largeTitle)
                            .foregroundColor(.secondary)
                        TextField("0.00", text: $totalBudget)
                            .font(.system(size: 48, weight: .bold))
                            .multilineTextAlignment(.center)
                            .keyboardType(.decimalPad)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(16)
                }
                .padding(.top, 40)
                
                Spacer()
                
                Button(action: {
                    if let newTotal = Double(totalBudget) {
                        onSave(newTotal)
                    }
                    dismiss()
                }) {
                    Text("Save Budget")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.pink)
                        .foregroundColor(.white)
                        .cornerRadius(14)
                }
                .padding(.horizontal)
                .padding(.bottom, 40)
            }
            .navigationTitle("Edit Budget")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

struct BudgetCategoryRow: View {
    let category: BudgetCategory
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(category.name)
                    .font(.headline)
                Text("$\(category.spent, specifier: "%.2f") of $\(category.allocated, specifier: "%.2f")")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text("$\(category.allocated - category.spent, specifier: "%.2f")")
                    .font(.headline)
                    .foregroundColor(category.allocated - category.spent >= 0 ? .green : .red)
                Text("remaining")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
}

#Preview {
    BudgetView()
        .environmentObject(AppState())
}
