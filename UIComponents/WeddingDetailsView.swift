import SwiftUI

struct WeddingDetailsView: View {
    @EnvironmentObject var appState: AppState
    @State private var coupleNames: String = ""
    @State private var weddingDate: Date = Date()
    @State private var location: String = ""
    @State private var showingSaveAlert = false
    
    var body: some View {
        Form {
            Section("Wedding Details") {
                TextField("Couple Names", text: $coupleNames)
                    .textInputAutocapitalization(.words)
                
                DatePicker("Wedding Date", selection: $weddingDate, displayedComponents: .date)
                
                TextField("Location", text: $location)
                    .textInputAutocapitalization(.words)
            }
            
            Section {
                Button("Save Details") {
                    saveDetails()
                }
                .frame(maxWidth: .infinity)
                .foregroundColor(.white)
                .padding()
                .background(Color("AccentColor"))
                .cornerRadius(8)
            }
        }
        .navigationTitle("Wedding Details")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            coupleNames = appState.weddingDetails.coupleNames
            weddingDate = appState.weddingDetails.date
            location = appState.weddingDetails.location
        }
        .alert("Details Saved", isPresented: $showingSaveAlert) {
            Button("OK", role: .cancel) { }
        }
    }
    
    private func saveDetails() {
        appState.weddingDetails = WeddingDetails(
            coupleNames: coupleNames,
            date: weddingDate,
            location: location
        )
        appState.updateCurrentWeddingMembership(with: appState.weddingDetails)
        // Save to DataStore
        _ = appState.dataStore.save(appState.weddingDetails, to: "wedding_details.json")
        if let weddingId = appState.weddingId {
            Task {
                do {
                    try await appState.cloudKitSync.saveWedding(appState.weddingDetails, weddingId: weddingId)
                } catch {
                    print("Failed to sync wedding details to CloudKit: \(error)")
                }
            }
        }
        showingSaveAlert = true
    }
}
