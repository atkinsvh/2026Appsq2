import SwiftUI
import Charts

struct BudgetHeaderReplacement: View {
    @Binding var categories: [BudgetCategory]
    var totalBudget: Double
    var totalSpent: Double
    var remaining: Double
    
    var body: some View {
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
}
