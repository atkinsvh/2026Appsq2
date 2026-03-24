import SwiftUI

struct SequentialGuestRSVPView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    
    // Current step state
    @State private var currentStep: Int = 0
    @State private var guestName: String = ""
    @State private var rsvpStatus: RSVPStatus = .noResponse
    @State private var mealChoice: String = ""
    @State private var dietaryNotes: String = ""
    @State private var partySize: Int = 1
    @State private var familyNote: String = "" // For declined guests
    @State private var songRequest: String = ""
    @State private var showingSuccess = false
    
    // Progress tracking
    private let totalStepsForAttending = 7
    private let totalStepsForDeclined = 4
    
    // Meal options - from wedding details or defaults
    private var mealOptions: [(String, String, String)] {
        let defaults: [(String, String, String)] = [
            ("Chicken", "🍗", "Grilled chicken breast"),
            ("Beef", "🥩", "Prime rib / steak"),
            ("Fish", "🐟", "Atlantic salmon"),
            ("Vegetarian", "🥗", "Garden vegetable"),
            ("Vegan", "🌱", "Plant-based meal"),
            ("Other", "🍽️", "Other selection")
        ]
        if appState.weddingDetails.mealOptions.isEmpty {
            return defaults
        }
        return appState.weddingDetails.mealOptions.enumerated().map { index, name in
            let emoji = ["🍗", "🥩", "🐟", "🥗", "🌱", "🍽️", "🥦", "🍝", "🥘"].suffix(from: index % 9).first ?? "🍽️"
            return (name, String(emoji), name)
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Progress bar
                progressIndicator
                    .padding(.vertical, 12)
                
                // Content area
                ScrollView {
                    VStack(spacing: 20) {
                        stepContent
                    }
                    .padding()
                }
                
                // Navigation buttons
                navButtons
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("You're Invited!")
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                preloadExistingRSVP()
            }
            .alert("RSVP Submitted!", isPresented: $showingSuccess) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text("Thank you for responding! The couple can't wait to celebrate with you!")
            }
        }
    }
    
    private var progressIndicator: some View {
        let totalSteps = rsvpStatus == .declined ? totalStepsForDeclined : totalStepsForAttending
        let progress = Double(currentStep + 1) / Double(totalSteps)
        
        return VStack(spacing: 8) {
            HStack {
                Text("Step \(currentStep + 1) of \(totalSteps)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(Int(progress * 100))% complete")
                    .font(.caption)
                    .foregroundColor(.pink)
            }
            .padding(.horizontal, 16)
            
            GeometryReader { geometry in
                Capsule()
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: 4)
                    .overlay(
                        Capsule()
                            .fill(Color.pink)
                            .frame(width: geometry.size.width * progress)
                            .frame(maxWidth: .infinity, alignment: .leading),
                        alignment: .leading
                    )
            }
            .frame(height: 4)
            .padding(.horizontal, 16)
        }
    }
    
    @ViewBuilder
    private var stepContent: some View {
        switch currentStep {
        case 0:
            // Name step
            VStack(spacing: 16) {
                Image("HeartLarge")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 80, height: 80)
                    .opacity(0.8)
                
                Text("Welcome!")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("What's your name?")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                TextField("Enter your name", text: $guestName)
                    .textFieldStyle(.plain)
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .padding(.horizontal)
            }
            
        case 1:
            // RSVP step
            VStack(spacing: 16) {
                Text("Will you attend?")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("We'd love to celebrate with you!")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                HStack(spacing: 20) {
                    RSVPButton(
                        title: "Can't Wait!",
                        icon: "heart.fill",
                        color: .green,
                        isSelected: rsvpStatus == .attending
                    ) {
                        withAnimation {
                            rsvpStatus = .attending
                        }
                    }
                    
                    RSVPButton(
                        title: "Can't Come",
                        icon: "xmark.circle.fill",
                        color: .red,
                        isSelected: rsvpStatus == .declined
                    ) {
                        withAnimation {
                            rsvpStatus = .declined
                        }
                    }
                }
                .padding(.horizontal)
            }
            
        case 2:
            // Meal choice (attending) or Family note (declined)
            if rsvpStatus == .attending {
                VStack(spacing: 16) {
                    Text("Dinner Options")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("What would you like to eat?")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                        ForEach(mealOptions, id: \.0) { option in
                            Button(action: { mealChoice = option.0 }) {
                                VStack(spacing: 6) {
                                    Text(option.1)
                                        .font(.title)
                                    Text(option.0)
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    Text(option.2)
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(mealChoice == option.0 ? Color.pink.opacity(0.2) : Color(.systemGray6))
                                .foregroundColor(mealChoice == option.0 ? .pink : .primary)
                                .cornerRadius(10)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(mealChoice == option.0 ? Color.pink : Color.clear, lineWidth: 2)
                                )
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            } else {
                VStack(spacing: 16) {
                    Image("HeartLarge")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 60, height: 60)
                        .opacity(0.6)
                    
                    Text("We'll Miss You!")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Tell us who will miss you at the wedding")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    
                    TextField("e.g., Grandma, Aunt Sue, Best friend", text: $familyNote)
                        .textFieldStyle(.plain)
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(12)
                        .padding(.horizontal)
                }
            }
            
        case 3:
            // Party size (attending) or Review (declined)
            if rsvpStatus == .attending {
                VStack(spacing: 16) {
                    Text("Party Size")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("How many in your party?")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Stepper("Number of guests: \(partySize)", value: $partySize, in: 1...5)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                        .padding(.horizontal)
                }
            } else {
                // Review step for declined guests
                reviewContent
            }
            
        case 4:
            // Dietary notes (attending) or skipped for declined
            if rsvpStatus == .attending {
                VStack(spacing: 16) {
                    Text("Notes & Dietary Needs")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Any meal preferences, allergies, or special notes?")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    TextEditor(text: $dietaryNotes)
                        .frame(height: 100)
                        .padding(8)
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                        .padding(.horizontal)
                }
            }
            
        case 5:
            if rsvpStatus == .attending {
                VStack(spacing: 16) {
                    Text("Music Request")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("Optional: add one song title or artist (max 100 characters, no links).")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)

                    TextField("Enter a song title or artist", text: $songRequest)
                        .textFieldStyle(.plain)
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(12)
                        .padding(.horizontal)
                        .onChange(of: songRequest) { _, newValue in
                            let trimmed = String(newValue.prefix(100))
                            if trimmed != newValue {
                                songRequest = trimmed
                            }
                        }

                    Text("\(songRequest.count)/100")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

        case 6:
            // Review for attending guests
            reviewContent
            
        default:
            EmptyView()
        }
    }
    
    private var reviewContent: some View {
        VStack(spacing: 16) {
            Text("Review Your RSVP")
                .font(.title2)
                .fontWeight(.bold)
                .padding(.top)
            
            VStack(spacing: 12) {
                reviewRow("Name", guestName)
                reviewRow("Will Attend", rsvpStatus == .attending ? "Yes" : "No")
                
                if rsvpStatus == .attending {
                    reviewRow("Meal Choice", mealChoice.isEmpty ? "Not selected" : mealChoice)
                    reviewRow("Party Size", "\(partySize)")
                    if !dietaryNotes.isEmpty {
                        reviewRow("Notes", dietaryNotes)
                    }
                    if !songRequest.isEmpty {
                        reviewRow("Song Request", songRequest)
                    }
                } else if rsvpStatus == .declined {
                    if !familyNote.isEmpty {
                        reviewRow("Will Miss", familyNote)
                    }
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .padding(.horizontal)
            
            Text("Your response is being saved and synced with the couple.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
    }
    
    private func reviewRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.headline)
        }
    }
    
    private var navButtons: some View {
        HStack {
            if currentStep > 0 {
                Button(action: {
                    withAnimation {
                        currentStep -= 1
                    }
                }) {
                    Text("Back")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(.systemGray6))
                        .foregroundColor(.primary)
                        .cornerRadius(12)
                }
                .padding(.leading)
            }
            
            Button(action: handleNext) {
                Text(currentStep == (rsvpStatus == .declined ? totalStepsForDeclined : totalStepsForAttending) - 1 ? "Submit" : "Continue")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(shouldProceed ? Color.pink : Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            .disabled(!shouldProceed)
            .padding(.horizontal, currentStep > 0 ? 0 : 16)
            .padding(.trailing)
        }
        .padding(.bottom)
    }
    
    private var shouldProceed: Bool {
        switch currentStep {
        case 0: return !guestName.isEmpty
        case 1: return rsvpStatus != .noResponse
        case 2: return rsvpStatus == .attending ? !mealChoice.isEmpty : true
        case 3: return true // Always proceed (declined goes to review, attending continues)
        case 4: return true // Dietary notes are optional
        case 5: return !containsLink(songRequest)
        case 6: return true // Always submit review
        default: return false
        }
    }
    
    private func handleNext() {
        let totalSteps = rsvpStatus == .declined ? totalStepsForDeclined : totalStepsForAttending
        
        // Build/update RSVP at each step
        let rsvp = GuestRSVP(
            invitationCode: appState.currentInvitationCode ?? "",
            guestName: guestName,
            rsvpStatus: rsvpStatus,
            mealChoice: rsvpStatus == .attending ? (mealChoice.isEmpty ? nil : mealChoice) : nil,
            dietaryNotes: dietaryNotes.isEmpty ? nil : dietaryNotes,
            partySize: partySize,
            songRequest: songRequest.isEmpty ? nil : songRequest
        )
        
        // Update in AppState (which also syncs to CloudKit)
        appState.updateGuestRSVPProgress(rsvp)
        
        if currentStep < totalSteps - 1 {
            withAnimation {
                currentStep += 1
            }
        } else {
            // Final submit
            appState.submitGuestRSVP(rsvp)
            showingSuccess = true
        }
    }
    
    private func preloadExistingRSVP() {
        guard let existingRSVP = appState.guestRSVP else { return }
        
        if guestName.isEmpty {
            guestName = existingRSVP.guestName
        }
        if rsvpStatus == .noResponse {
            rsvpStatus = existingRSVP.rsvpStatus
        }
        if mealChoice.isEmpty {
            mealChoice = existingRSVP.mealChoice ?? ""
        }
        if dietaryNotes.isEmpty {
            dietaryNotes = existingRSVP.dietaryNotes ?? ""
        }
        if partySize == 1 {
            partySize = existingRSVP.partySize
        }
        if songRequest.isEmpty {
            songRequest = existingRSVP.songRequest ?? ""
        }
    }

    private func containsLink(_ text: String) -> Bool {
        let lowered = text.lowercased()
        return lowered.contains("http://") || lowered.contains("https://") || lowered.contains("www.")
    }
}

// MARK: - RSVPButton Component
struct RSVPButton: View {
    let title: String
    let icon: String
    let color: Color
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title)
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .background(isSelected ? color.opacity(0.2) : Color(.systemGray6))
            .foregroundColor(isSelected ? color : .secondary)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? color : Color.clear, lineWidth: 2)
            )
        }
    }
}

// MARK: - Preview
#Preview {
    SequentialGuestRSVPView()
        .environmentObject(AppState())
}
