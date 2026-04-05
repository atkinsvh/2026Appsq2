import SwiftUI

// FIXED BUG-10: Removed @available(iOS 17.0, *) — deployment target is already iOS 17.
// FIXED BUG-10: Removed double-discard `_ = _ =` on DataStore.save call.
struct CoupleLifeView: View {
    @State var financialNotes: String = ""
    @State var householdNotes: String = ""
    @State var communicationNotes: String = ""
    @State var legalNotes: String = ""

    var body: some View {
        Form {
            Section("Financial Expectations") {
                TextEditor(text: $financialNotes)
                    .frame(minHeight: 100)
            }
            Section("Household Division") {
                TextEditor(text: $householdNotes)
                    .frame(minHeight: 100)
            }
            Section("Communication Habits") {
                TextEditor(text: $communicationNotes)
                    .frame(minHeight: 100)
            }
            Section("Legal Preparation") {
                TextEditor(text: $legalNotes)
                    .frame(minHeight: 100)
            }
        }
        .navigationTitle("Couple Life")
        .onAppear {
            if let data = DataStore.shared.load([String: String].self, from: "couplelife.json") {
                financialNotes      = data["financial"]      ?? ""
                householdNotes      = data["household"]      ?? ""
                communicationNotes  = data["communication"]  ?? ""
                legalNotes          = data["legal"]          ?? ""
            }
        }
        .onDisappear {
            let data = [
                "financial":     financialNotes,
                "household":     householdNotes,
                "communication": communicationNotes,
                "legal":         legalNotes
            ]
            // BUG-10 FIX: was `_ = _ = DataStore.shared.save(...)` — double discard
            _ = DataStore.shared.save(data, to: "couplelife.json")
        }
    }
}
