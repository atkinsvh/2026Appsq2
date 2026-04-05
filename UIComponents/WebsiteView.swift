import SwiftUI
import WebKit
#if canImport(UIKit)
import UIKit
#endif

// ─────────────────────────────────────────────
// FIXED BUG-06 — WebsiteView.loadSavedWebsite
// Was: synchronous Data(contentsOf:) on the main thread → UI freeze on large HTML files.
// Fix: move the disk read to a background Task, then publish results on MainActor.
// ─────────────────────────────────────────────
struct WebsiteView: View {
    @EnvironmentObject var appState: AppState
    @State private var generatedHTML: String = ""
    @State private var isGenerating = false
    @State private var showingPreview = false
    @State private var showingShare = false
    @State private var selectedTemplate: WebsiteTemplate = .classic
    @State private var generatedWebsiteURL: URL?
    @State private var generationErrorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    headerSection
                    templateSection
                    previewSection
                    generateButton
                }
                .padding()
            }
            .navigationTitle("Wedding Website")
            .sheet(isPresented: $showingPreview) {
                WebsitePreviewSheet(html: generatedHTML)
            }
            .sheet(isPresented: $showingShare) {
                if let url = generatedWebsiteURL {
                    ShareSheet(items: [url])
                }
            }
            .onAppear {
                loadSavedWebsite()
            }
        }
    }

    private var headerSection: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "globe")
                    .font(.system(size: 50))
                    .foregroundColor(.pink)
                Image("FloralInsignia")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 60, height: 60)
            }
            Text("Create Your Wedding Website")
                .font(.title2).fontWeight(.bold)
            Text("Share your wedding details with guests")
                .font(.subheadline).foregroundColor(.secondary).multilineTextAlignment(.center)
        }
        .padding(.vertical)
    }

    private var templateSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Choose a Template").font(.headline)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(WebsiteTemplate.allCases, id: \.self) { template in
                        TemplateCard(
                            name: template.rawValue,
                            image: template.icon,
                            isSelected: selectedTemplate == template
                        ) {
                            withAnimation(.spring(response: 0.3)) { selectedTemplate = template }
                        }
                    }
                }
            }
        }
    }

    private var previewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Website Preview").font(.headline)
                Spacer()
                if !generatedHTML.isEmpty {
                    Button("View") { showingPreview = true }
                }
            }
            VStack(spacing: 8) {
                previewRow("Couple Names",
                           appState.weddingDetails.coupleNames.isEmpty ? "Not set" : appState.weddingDetails.coupleNames)
                previewRow("Wedding Date", weddingDateText)
                previewRow("Location",
                           appState.weddingDetails.location.isEmpty ? "Not set" : appState.weddingDetails.location)
            }
        }
    }

    private func previewRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).font(.caption).foregroundColor(.secondary)
            Spacer()
            Text(value).font(.body).lineLimit(1)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }

    private var generateButton: some View {
        VStack(spacing: 12) {
            Button(action: generateWebsite) {
                HStack {
                    if isGenerating { ProgressView().tint(.white) }
                    else { Image(systemName: "wand.and.stars") }
                    Text(isGenerating ? "Generating..." : "Generate Website")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color("AccentColor"))
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .disabled(isGenerating)

            if !generatedHTML.isEmpty {
                Button(action: { showingShare = true }) {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                        Text("Share Website")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(.systemGray5))
                    .foregroundColor(.primary)
                    .cornerRadius(12)
                }
            }

            if let generationErrorMessage {
                Text(generationErrorMessage)
                    .font(.footnote)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var weddingDateText: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        return formatter.string(from: appState.weddingDetails.date)
    }

    private func generateWebsite() {
        isGenerating = true
        generationErrorMessage = nil

        let guests = appState.loadCurrentGuests()
        let attendingGuests = guests.filter { $0.rsvpStatus == .attending }

        let request = WebsiteGenerationRequest(
            coupleNames: appState.weddingDetails.coupleNames,
            date: weddingDateText,
            location: appState.weddingDetails.location,
            attendingGuests: attendingGuests,
            template: selectedTemplate
        )

        let result = WebsiteService.shared.generateWebsite(request: request)
        switch result {
        case .success(let generatedWebsite):
            generatedHTML = generatedWebsite.html
            generatedWebsiteURL = generatedWebsite.fileURL
        case .failure(let error):
            generationErrorMessage = error.localizedDescription
        }

        isGenerating = false
    }

    // BUG-06 FIX: Was `Data(contentsOf: url)` called synchronously on the main
    // thread inside `.onAppear`. For a large HTML file this freezes the UI while
    // the disk read completes. Moved to a background Task with MainActor publish.
    private func loadSavedWebsite() {
        Task.detached(priority: .userInitiated) {
            let url = FileManager.default
                .urls(for: .documentDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("wedding_website.html")

            guard let data = try? Data(contentsOf: url),
                  let html = String(data: data, encoding: .utf8) else { return }

            await MainActor.run {
                self.generatedHTML = html
                self.generatedWebsiteURL = url
            }
        }
    }
}

struct TemplateCard: View {
    let name: String
    let image: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: image)
                    .font(.title)
                    .foregroundColor(isSelected ? .white : .secondary)
                Text(name)
                    .font(.caption)
                    .fontWeight(isSelected ? .semibold : .regular)
                    .foregroundColor(isSelected ? .white : .primary)
            }
            .frame(width: 100, height: 80)
            .background(isSelected ? Color("AccentColor") : Color(.systemGray6))
            .cornerRadius(12)
        }
    }
}

struct WebsitePreviewSheet: View {
    let html: String
    @Environment(\.dismiss) private var dismiss
    @StateObject private var webViewModel = WebViewModel()

    var body: some View {
        NavigationStack {
            WebView(webViewModel: webViewModel, html: html)
                .ignoresSafeArea()
                .navigationTitle("Preview")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close") { dismiss() }
                    }
                    ToolbarItem(placement: .primaryAction) {
                        Button(action: { webViewModel.reload() }) {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                }
        }
    }
}

@MainActor
class WebViewModel: ObservableObject {
    var webView: WKWebView?
    func reload() { webView?.reload() }
}

struct WebView: UIViewRepresentable {
    @ObservedObject var webViewModel: WebViewModel
    let html: String

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webViewModel.webView = webView
        webView.loadHTMLString(html, baseURL: nil)
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        webView.loadHTMLString(html, baseURL: nil)
    }
}
