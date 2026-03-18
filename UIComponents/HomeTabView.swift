import SwiftUI

struct HomeTabView: View {
    var body: some View {
        TabView {
            DashboardView()
                .tabItem {
                    Label("Dashboard", systemImage: "heart.circle.fill")
                }
            
            GuestsView()
                .tabItem {
                    Label("Guests", systemImage: "person.3.fill")
                }
            
            BudgetView()
                .tabItem {
                    Label("Budget", systemImage: "creditcard.fill")
                }
            
            VendorsView()
                .tabItem {
                    Label("Vendors", systemImage: "bag.fill")
                }
            
            TimelineView()
                .tabItem {
                    Label("Timeline", systemImage: "calendar.badge.clock")
                }
            
            WebsiteView()
                .tabItem {
                    Label("Website", systemImage: "globe")
                }
        }
        .tint(Color("AccentColor"))
    }
}
