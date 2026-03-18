import SwiftUI
import Foundation

struct VendorDetailView: View {
    @State var vendor: Vendor
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        Form {
            Section("Vendor Information") {
                TextField("Name", text: $vendor.name)
                TextField("Category", text: $vendor.category)
            }
            
            Section("Contact") {
                TextField("Phone", text: Binding($vendor.phone, default: ""))
                TextField("Email", text: Binding($vendor.email, default: ""))
                TextField("Website", text: Binding($vendor.website, default: ""))
            }
            
            Section("Notes") {
                TextEditor(text: Binding($vendor.notes, default: ""))
            }
        }
        .navigationTitle("Vendor Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    dismiss()
                }
            }
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }
        }
    }
}