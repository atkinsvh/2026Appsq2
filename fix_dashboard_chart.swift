import SwiftUI
import Charts

struct GuestStatsChart: View {
    var guestStats: GuestStats
    
    var body: some View {
        VStack {
            if guestStats.total > 0 {
                Chart {
                    SectorMark(
                        angle: .value("Attending", guestStats.attending),
                        innerRadius: .ratio(0.6),
                        angularInset: 1.5
                    )
                    .cornerRadius(4)
                    .foregroundStyle(Color.green)
                    
                    SectorMark(
                        angle: .value("Pending", guestStats.pending),
                        innerRadius: .ratio(0.6),
                        angularInset: 1.5
                    )
                    .cornerRadius(4)
                    .foregroundStyle(Color.orange)
                    
                    SectorMark(
                        angle: .value("Declined", guestStats.total - guestStats.attending - guestStats.pending),
                        innerRadius: .ratio(0.6),
                        angularInset: 1.5
                    )
                    .cornerRadius(4)
                    .foregroundStyle(Color.red)
                }
                .frame(height: 120)
                .padding(.vertical, 8)
            } else {
                Text("No guests added yet")
                    .foregroundColor(.secondary)
                    .padding()
            }
        }
    }
}
