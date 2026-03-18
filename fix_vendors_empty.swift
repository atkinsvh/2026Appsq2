import SwiftUI

// Replace the empty state VStack in VendorsView with this:
if filteredVendors.isEmpty {
    if searchText.isEmpty && filter == nil {
        ContentUnavailableView {
            Label("No Vendors Yet", systemImage: "bag")
        } description: {
            Text("Keep track of your wedding vendors and their contact info.")
        } actions: {
            Button("Add Vendor") {
                showingAddVendor = true
            }
            .buttonStyle(.borderedProminent)
            .tint(.pink)
        }
    } else if !searchText.isEmpty {
        ContentUnavailableView.search
    } else {
        ContentUnavailableView("No Vendors Found", systemImage: "magnifyingglass", description: Text("Try changing your filter."))
    }
} else {
    List {
        // ...
    }
}
