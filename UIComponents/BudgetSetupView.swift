import SwiftUI

struct BudgetSetupView: View {
    @State private var budgetAmount = ""
    @State private var currency = "USD"
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Budget Setup")
                .font(.title2)
                .padding(.top, 20)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Amount")
                    .font(.headline)
                TextField("Enter budget amount", text: $budgetAmount)
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.decimalPad)
            }
            .padding(.horizontal, 24)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Currency")
                    .font(.headline)
                Picker("Currency", selection: $currency) {
                    Text("USD").tag("USD")
                    Text("EUR").tag("EUR")
                    Text("GBP").tag("GBP")
                }
                .pickerStyle(.segmented)
            }
            .padding(.horizontal, 24)
            
            Spacer()
            
            Button("Skip for now") {
                // Skip logic
            }
            .padding()
            .padding(.bottom, 40)
        }
    }
}