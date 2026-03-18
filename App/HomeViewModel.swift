import Foundation

@MainActor
class HomeViewModel: ObservableObject {
    @Published var weddingDetails: WeddingDetails?
    @Published var nextMilestones: [TimelineItem] = []
    @Published var isLoading = false
    
    private let weddingStore: WeddingStoreActor
    private let timelineStore: TimelineStoreActor
    
    init(weddingStore: WeddingStoreActor, timelineStore: TimelineStoreActor) {
        self.weddingStore = weddingStore
        self.timelineStore = timelineStore
        Task { await loadData() }
    }
    
    func loadData() async {
        isLoading = true
        weddingDetails = await weddingStore.loadWeddingDetails()
        let timeline = await timelineStore.loadTimeline()
        nextMilestones = timeline.filter { !$0.completed }.prefix(3).map { $0 }
        isLoading = false
    }
    
    func refresh() async {
        await loadData()
    }
}