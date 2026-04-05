import SwiftUI

struct VendorsView: View {
    @EnvironmentObject var appState: AppState
    @State private var vendors: [Vendor] = []
    @State private var selectedCategory: String? = nil
    @State private var showingAddVendor = false
    @State private var searchText = ""

    let categories = ["All", "Venue", "Catering", "Photography", "Music",
                      "Florist", "Bakery", "Attire", "Officiant", "Transportation", "Other"]

    var filteredVendors: [Vendor] {
        var result = vendors
        if let category = selectedCategory, category != "All" {
            result = result.filter { $0.category == category }
        }
        if !searchText.isEmpty {
            result = result.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
        return result
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(categories, id: \.self) { category in
                            CategoryChip(
                                title: category,
                                isSelected: selectedCategory == category
                                    || (selectedCategory == nil && category == "All")
                            ) {
                                selectedCategory = category == "All" ? nil : category
                            }
                        }
                    }
                    .padding()
                }
                .background(Color(.systemGray6))

                if filteredVendors.isEmpty {
                    if searchText.isEmpty && selectedCategory == nil {
                        ContentUnavailableView {
                            Label("No Vendors Yet", systemImage: "bag")
                        } description: {
                            Text("Keep track of your wedding vendors and their contact info.")
                        } actions: {
                            Button("Add Vendor") { showingAddVendor = true }
                                .buttonStyle(.borderedProminent)
                                .tint(.pink)
                        }
                    } else if !searchText.isEmpty {
                        ContentUnavailableView.search
                    } else {
                        ContentUnavailableView(
                            "No Vendors Found",
                            systemImage: "magnifyingglass",
                            description: Text("Try changing your filter.")
                        )
                    }
                } else {
                    List {
                        ForEach(filteredVendors, id: \.id) { vendor in
                            VendorRowView(vendor: vendor)
                        }
                        .onDelete(perform: deleteVendors)
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Vendors")
            .searchable(text: $searchText, prompt: "Search vendors")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { showingAddVendor = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddVendor) {
                AddVendorView { newVendor in
                    vendors.append(newVendor)
                    saveVendors()
                    Haptics.shared.notify(.success)
                }
            }
            .onAppear { loadVendors() }
            .onChange(of: appState.weddingId) { _, _ in
                loadVendors()
            }
        }
    }

    private func loadVendors() {
        vendors = appState.loadCurrentVendors()
    }

    // BUG-10 FIX: was `_ = _ = DataStore.shared.save(...)` — redundant double discard
    private func saveVendors() {
        appState.saveCurrentVendors(vendors)

        if let weddingId = appState.weddingId {
            Task {
                do {
                    try await appState.cloudKitSync.saveVendors(vendors, weddingId: weddingId)
                } catch {
                    print("CloudKit: Failed to save vendors: \(error)")
                }
            }
        } else {
            print("CloudKit: Warning — No weddingId when saving vendors. Complete onboarding first.")
        }
    }

    private func deleteVendors(at offsets: IndexSet) {
        vendors.remove(atOffsets: offsets)
        saveVendors()
    }
}

struct CategoryChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(isSelected ? .semibold : .regular)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(isSelected ? Color("AccentColor") : Color(.systemGray5))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(20)
        }
    }
}

struct VendorRowView: View {
    let vendor: Vendor

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(vendor.name)
                    .font(.headline)
                Text(vendor.category)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                if let phone = vendor.phone, !phone.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "phone").font(.caption)
                        Text(phone).font(.caption)
                    }
                    .foregroundColor(.secondary)
                }
            }

            Spacer()

            VStack(spacing: 8) {
                if let phone = vendor.phone, !phone.isEmpty {
                    Button(action: { callVendor(phone: phone) }) {
                        Image(systemName: "phone.circle.fill")
                            .font(.title2)
                            .foregroundColor(.green)
                    }
                }
                if let email = vendor.email, !email.isEmpty {
                    Button(action: { emailVendor(email: email) }) {
                        Image(systemName: "envelope.circle.fill")
                            .font(.title2)
                            .foregroundColor(.blue)
                    }
                }
            }
        }
        .padding(.vertical, 8)
    }

    private func callVendor(phone: String) {
        guard let url = URL(string: "tel:\(phone)") else { return }
        UIApplication.shared.open(url)
    }

    private func emailVendor(email: String) {
        guard let url = URL(string: "mailto:\(email)") else { return }
        UIApplication.shared.open(url)
    }
}

struct AddVendorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var category = "Venue"
    @State private var phone = ""
    @State private var email = ""
    @State private var website = ""
    @State private var notes = ""

    let onSave: (Vendor) -> Void

    private let categories = ["Venue", "Catering", "Photography", "Music",
                               "Florist", "Bakery", "Attire", "Officiant",
                               "Transportation", "Other"]

    var body: some View {
        NavigationStack {
            Form {
                Section("Vendor Information") {
                    TextField("Name", text: $name)
                    Picker("Category", selection: $category) {
                        ForEach(categories, id: \.self) { cat in
                            Text(cat).tag(cat)
                        }
                    }
                }

                Section("Contact") {
                    TextField("Phone", text: $phone).keyboardType(.phonePad)
                    TextField("Email", text: $email)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                    TextField("Website", text: $website)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                }

                Section("Notes") {
                    TextEditor(text: $notes).frame(minHeight: 100)
                }
            }
            .navigationTitle("Add Vendor")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let vendor = Vendor(
                            name: name,
                            category: category,
                            phone: phone.isEmpty ? nil : phone,
                            email: email.isEmpty ? nil : email,
                            website: website.isEmpty ? nil : website,
                            notes: notes.isEmpty ? nil : notes
                        )
                        onSave(vendor)
                        dismiss()
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
    }
}
