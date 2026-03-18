import SwiftUI

// Replace the items.isEmpty section with ContentUnavailableView
if items.isEmpty {
    ContentUnavailableView {
        Label("No Timeline Yet", image: "FloralRing")
            .opacity(0.8)
    } description: {
        Text("Generate a timeline based on your wedding date")
    } actions: {
        Button("Generate Timeline", action: generateTimeline)
            .buttonStyle(.borderedProminent)
            .tint(.pink)
    }
    .listRowBackground(Color.clear)
}
