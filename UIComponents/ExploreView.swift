import SwiftUI

// Explore screen with placeholder content for discovery features
struct ExploreView: View {
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Search Bar Placeholder
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.gray)
                        Text("Search for content...")
                            .foregroundColor(.gray)
                            .font(.body)
                        Spacer()
                    }
                    .frame(height: 44)
                    .padding(.horizontal, 16)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(10)
                    .padding(.horizontal)
                    
                    // Featured Section
                    VStack(alignment: .leading, spacing: 15) {
                        Text("Featured")
                            .font(.title2)
                            .fontWeight(.bold)
                            .padding(.horizontal)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 15) {
                                // Placeholder cards for featured content
                                ForEach(0..<5, id: \.self) { index in
                                    FeaturedCard(title: "Item \(index + 1)")
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                    
                    // Categories Section
                    VStack(alignment: .leading, spacing: 15) {
                        Text("Categories")
                            .font(.title2)
                            .fontWeight(.bold)
                            .padding(.horizontal)
                        
                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: 15) {
                            // Placeholder category items
                            ForEach(["Technology", "Design", "Business", "Lifestyle"], id: \.self) { category in
                                CategoryCard(title: category)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }
            .navigationTitle("Explore")
        }
    }
}

// Reusable component for featured content cards
struct FeaturedCard: View {
    let title: String
    
    var body: some View {
        VStack {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.gray.opacity(0.3))
                .frame(width: 150, height: 120)
                .overlay(
                    Image(systemName: "photo")
                        .font(.system(size: 30))
                        .foregroundColor(.gray)
                )
            
            Text(title)
                .font(.caption)
                .foregroundColor(.primary)
                .lineLimit(1)
        }
    }
}

// Reusable component for category cards
struct CategoryCard: View {
    let title: String
    
    var body: some View {
        VStack {
            RoundedRectangle(cornerRadius: 15)
                .fill(LinearGradient(
                    gradient: Gradient(colors: [.blue.opacity(0.3), .purple.opacity(0.3)]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
                .frame(height: 80)
                .overlay(
                    Image(systemName: "folder")
                        .font(.system(size: 25))
                        .foregroundColor(.white)
                )
            
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
        }
    }
}

#Preview {
    ExploreView()
}