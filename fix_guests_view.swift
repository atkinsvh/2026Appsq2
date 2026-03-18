import SwiftUI
import Charts

struct GuestStatsChart: View {
    var guestStats: GuestStats
    
    var body: some View {
        HStack {
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
                .frame(width: 80, height: 80)
                .padding(.trailing, 16)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Circle().fill(Color.green).frame(width: 8, height: 8)
                    Text("Attending: \(guestStats.attending)")
                        .font(.caption)
                }
                HStack {
                    Circle().fill(Color.orange).frame(width: 8, height: 8)
                    Text("Pending: \(guestStats.pending)")
                        .font(.caption)
                }
                HStack {
                    Circle().fill(Color.red).frame(width: 8, height: 8)
                    Text("Declined: \(guestStats.total - guestStats.attending - guestStats.pending)")
                        .font(.caption)
                }
            }
            Spacer()
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
}
