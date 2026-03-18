import SwiftUI

// Replace the ForEach block in BudgetView with this:
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
