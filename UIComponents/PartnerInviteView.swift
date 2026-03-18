import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct PartnerInviteView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var partnerLink = ""
    @State private var showingShareSheet = false
    @State private var shareText = ""
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 30) {
                Spacer()
                
                Image(systemName: "heart.circle.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.pink)
                
                VStack(spacing: 12) {
                    Text("Invite Your Partner")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text("Collaborate on planning your special day together")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                
                VStack(spacing: 16) {
                    FeatureRow(icon: "person.2.fill", title: "Share Planning", description: "Both partners can manage details")
                    FeatureRow(icon: "arrow.triangle.2.circlepath", title: "Real-time Sync", description: "Changes update instantly")
                    FeatureRow(icon: "lock.shield.fill", title: "Private", description: "Only you and your partner can see")
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(16)
                .padding(.horizontal)
                
                Spacer()
                
                VStack(spacing: 12) {
                    Button(action: generateAndShare) {
                        HStack {
                            Image(systemName: "square.and.arrow.up")
                            Text("Share Invite Link")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color("AccentColor"))
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    
                    Button("Skip for Now") {
                        dismiss()
                    }
                    .foregroundColor(.secondary)
                }
                .padding(.horizontal)
                .padding(.bottom, 30)
            }
        }
        .sheet(isPresented: $showingShareSheet) {
            ShareSheet(items: [shareText])
        }
    }
    
    private func generateAndShare() {
        let appStoreLink = "https://apps.apple.com/app/vow-planner/idXXXXXXXXX"
        let websiteLink = "https://goodvibez.vowplanner.life"
        
        Task {
            do {
                // Generate co-planner code via CloudKit
                let partnerCode = try await appState.generateCoPlannerCode()
                
                let name = appState.weddingDetails.coupleNames.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
                let date = ISO8601DateFormatter().string(from: appState.weddingDetails.date)
                
                partnerLink = "\(websiteLink)/invite?code=\(partnerCode)&name=\(name)&date=\(date)"
                
                shareText = """
                💍 Let's plan our wedding together!
                
                Join me on VowPlanner - download "Vow Planner" from the App Store or visit:
                \(websiteLink)
                
                Use invite code: \(partnerCode)
                
                See you at the altar! 👰‍♀️🤵
                """
                
                await MainActor.run {
                    showingShareSheet = true
                }
            } catch {
                print("Error generating co-planner code: \(error)")
                // Fallback to local code generation
                let fallbackCode = String((0..<6).map { _ in "ABCDEFGHJKLMNPQRSTUVWXYZ23456789".randomElement()! })
                shareText = """
                💍 Let's plan our wedding together!
                
                Join me on VowPlanner - download "Vow Planner" from the App Store or visit:
                \(websiteLink)
                
                Use invite code: \(fallbackCode)
                
                See you at the altar! 👰‍♀️🤵
                """
                showingShareSheet = true
            }
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.pink)
                .frame(width: 40)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
}
