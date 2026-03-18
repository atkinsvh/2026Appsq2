import SwiftUI

enum Route: Hashable {
    case home
    case weddingDetails
    case timeline
    case guests
    case guestDetail(Guest)
    case budget
    case vendors
    case vendorDetail(Vendor)
    case weddingPage
    case dashboard
    case profile
    case explore
    case onboarding
    case partnerInvite
    case couplesLife
}

@MainActor
class NavigationCoordinator: ObservableObject {
    @Published var path = NavigationPath()
    
    func push(_ route: Route) {
        path.append(route)
    }
    
    func pop() {
        if !path.isEmpty {
            path.removeLast()
        }
    }
    
    func popToRoot() {
        path = NavigationPath()
    }
}

struct NavigationStackView<Content: View>: View {
    @StateObject private var coordinator = NavigationCoordinator()
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        SwiftUI.NavigationStack(path: $coordinator.path) {
            content
                .navigationDestination(for: Route.self) { route in
                    switch route {
                    case .home:
                        HomeTabView()
                    case .weddingDetails:
                        WeddingDetailsView()
                    case .timeline:
                        TimelineView()
                    case .guests:
                        GuestsView()
                    case .guestDetail(let guest):
                        GuestDetailView(guest: guest)
                    case .budget:
                        BudgetView()
                    case .vendors:
                        VendorsView()
                    case .vendorDetail(let vendor):
                        VendorDetailView(vendor: vendor)
                    case .weddingPage:
                        WebsiteView()
                    case .dashboard:
                        DashboardView()
                    case .profile:
                        ProfileView()
                    case .explore:
                        ExploreView()
                    case .onboarding:
                        OnboardingView()
                    case .partnerInvite:
                        PartnerInviteView()
                    case .couplesLife:
                        CoupleLifeView()
                    }
                }
        }
        .environmentObject(coordinator)
    }
}
