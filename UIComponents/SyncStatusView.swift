import SwiftUI

/// Shows the current sync status with a heartwarming touch
struct SyncStatusView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        HStack(spacing: 6) {
            // Sync icon with animation
            Group {
                switch appState.dataStore.syncStatus {
                case .idle:
                    Image(systemName: "cloud.fill")
                        .foregroundColor(.green)
                    
                case .syncing(let message):
                    ProgressView()
                        .scaleEffect(0.7)
                    Text(message)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                case .synced:
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    
                case .error(let message):
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text(message)
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
            .transition(.opacity)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

/// Sync status in the navigation bar
struct SyncStatusNavBar: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        HStack(spacing: 4) {
            switch appState.dataStore.syncStatus {
            case .synced:
                Image(systemName: "cloud.fill")
                    .foregroundColor(.green)
                    .transition(.opacity)
            case .syncing:
                ProgressView()
                    .scaleEffect(0.6)
            case .error:
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
            case .idle:
                EmptyView()
            }
        }
        .frame(width: 20, height: 20)
    }
}

/// A subtle sync indicator for the bottom of views
struct SyncFooterView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        VStack(spacing: 2) {
            Divider()
            HStack {
                Spacer()
                switch appState.dataStore.syncStatus {
                case .idle:
                    Text("✓ Saved locally")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                case .syncing:
                    Text("☁️ Saving to iCloud...")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                case .synced:
                    Text("☁️ Saved with love")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                case .error:
                    Text("⚠️ Sync paused")
                        .font(.caption2)
                        .foregroundColor(.orange)
                }
                Spacer()
            }
            .padding(.vertical, 4)
        }
    }
}
