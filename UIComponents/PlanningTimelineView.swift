import SwiftUI

struct TimelineView: View {
    @State private var items: [TimelineItem] = []
    @EnvironmentObject var appState: AppState

    var upcomingItems: [TimelineItem] {
        items.filter { !$0.completed }.sorted { $0.dueDate < $1.dueDate }
    }

    var completedItems: [TimelineItem] {
        items.filter { $0.completed }
    }

    var body: some View {
        NavigationStack {
            List {
                if !upcomingItems.isEmpty {
                    Section("Upcoming") {
                        ForEach(upcomingItems, id: \.id) { item in
                            TimelineItemRow(item: item) { updatedItem in
                                updateItem(updatedItem)
                            }
                        }
                    }
                }

                if !completedItems.isEmpty {
                    Section("Completed") {
                        ForEach(completedItems, id: \.id) { item in
                            TimelineItemRow(item: item) { updatedItem in
                                updateItem(updatedItem)
                            }
                        }
                    }
                }

                if items.isEmpty {
                    ContentUnavailableView {
                        Label {
                            Text("No Timeline Yet")
                        } icon: {
                            Image("FloralRing")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 80, height: 80)
                                .opacity(0.8)
                        }
                    } description: {
                        Text("Generate a timeline based on your wedding date")
                    } actions: {
                        Button("Generate Timeline", action: generateTimeline)
                            .buttonStyle(.borderedProminent)
                            .tint(.pink)
                    }
                    .listRowBackground(Color.clear)
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Timeline")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button(action: addItem) {
                            Label("Add Item", systemImage: "plus")
                        }
                        Button(action: generateTimeline) {
                            Label("Generate Timeline", systemImage: "wand.and.stars")
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .onAppear {
                loadTimeline()
            }
            .onChange(of: appState.weddingId) { _, _ in
                loadTimeline()
            }
        }
    }

    private func loadTimeline() {
        items = appState.loadCurrentTimeline()
        if items.isEmpty && !appState.weddingDetails.coupleNames.isEmpty {
            generateTimeline()
        }
    }

    // BUG-10 FIX: was `_ = _ = DataStore.shared.save(...)` — redundant double discard
    private func saveTimeline() {
        appState.saveCurrentTimeline(items)
    }

    private func updateItem(_ item: TimelineItem) {
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items[index] = item
            saveTimeline()
        }
    }

    private func addItem() {
        let newItem = TimelineItem(
            title: "New Task",
            dueDate: Date(),
            completed: false
        )
        items.append(newItem)
        saveTimeline()
    }

    private func generateTimeline() {
        items = generateDefaultTimeline(from: appState.weddingDetails.date)
        saveTimeline()
    }

    private func generateDefaultTimeline(from date: Date) -> [TimelineItem] {
        var result: [TimelineItem] = []
        let calendar = Calendar.current

        let tasks = [
            (months: 12, title: "Book Venue"),
            (months: 10, title: "Hire Photographer"),
            (months: 8,  title: "Send Save-the-Dates"),
            (months: 6,  title: "Book Caterer"),
            (months: 6,  title: "Choose Florist"),
            (months: 5,  title: "Buy Wedding Rings"),
            (months: 4,  title: "Send Invitations"),
            (months: 4,  title: "Book Musician/DJ"),
            (months: 3,  title: "Finalize Menu"),
            (months: 3,  title: "Buy Wedding Cake"),
            (months: 2,  title: "Plan Honeymoon"),
            (months: 1,  title: "Final Fitting"),
            (months: 1,  title: "Apply for Marriage License"),
            (months: 0,  title: "Wedding Day!")
        ]

        for task in tasks {
            if let dueDate = calendar.date(byAdding: .month, value: -task.months, to: date) {
                result.append(TimelineItem(title: task.title, dueDate: dueDate))
            }
        }

        return result.sorted { $0.dueDate > $1.dueDate }
    }
}

struct TimelineItemRow: View {
    let item: TimelineItem
    let onUpdate: (TimelineItem) -> Void

    var body: some View {
        HStack {
            Button(action: toggleComplete) {
                Image(systemName: item.completed ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundColor(item.completed ? .green : .secondary)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.headline)
                    .strikethrough(item.completed)
                    .foregroundColor(item.completed ? .secondary : .primary)

                Text(item.dueDate, style: .date)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Text(daysUntilText)
                .font(.caption)
                .fontWeight(.medium)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(daysUntilColor.opacity(0.2))
                .foregroundColor(daysUntilColor)
                .cornerRadius(8)
        }
        .padding(.vertical, 4)
    }

    private func toggleComplete() {
        var updated = item
        updated.completed.toggle()
        onUpdate(updated)

        if updated.completed {
            Haptics.shared.notify(.success)
        } else {
            Haptics.shared.play(.light)
        }
    }

    private var daysUntilText: String {
        let days = Calendar.current.dateComponents([.day], from: Date(), to: item.dueDate).day ?? 0
        if days < 0       { return "\(abs(days))d ago" }
        else if days == 0 { return "Today" }
        else if days == 1 { return "Tomorrow" }
        else              { return "\(days)d" }
    }

    private var daysUntilColor: Color {
        let days = Calendar.current.dateComponents([.day], from: Date(), to: item.dueDate).day ?? 0
        if item.completed { return .green }
        else if days < 0  { return .red }
        else if days < 30 { return .orange }
        else              { return .blue }
    }
}
