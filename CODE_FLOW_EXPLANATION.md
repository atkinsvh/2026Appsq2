# VowPlanner Code Flow Explanation

## Current Flow Architecture

### 1. App Entry (VowPlannerApp.swift)
- Initializes `AppState`
- Sets up ContentView as main entry

### 2. ContentView (Entry Point)
```swift
if !appState.onboardingCompleted {
    OnboardingView()      // First-time users
} else if appState.isGuestMode {
    GuestModeEntryView()  // Guests who entered code
} else {
    MainTabView()         // Hosts (planning a wedding)
}
```

### 3. Onboarding Flow (OnboardingView.swift)

#### Steps:
1. **Welcome** → "Get Started"
2. **Role Selection** → Choose Host or Guest
   - Host → Wedding Details
   - Guest → Enter Invitation Code
3. **Wedding Details** (Host) → Couple names, date, location
4. **Invite Partner** (Host) → Generate code or skip
5. **Wedding Phases** → Overview of timeline
6. **Complete** → Sets `appState.onboardingCompleted = true`

### 4. Host Flow (MainTabView)
- DashboardView
- GuestsView (with code generation)
- BudgetView
- VendorsView
- TimelineView
- WebsiteView

### 5. Guest Flow (GuestModeEntryView)
- RSVPFormView (if no RSVP submitted)
- GuestThankYouView (after RSVP)

## Key Files & Their Roles

| File | Purpose |
|------|---------|
| VowPlannerApp.swift | App entry, initializes services |
| ContentView.swift | Route between Onboarding/Guest/Host |
| OnboardingView.swift | New user setup (5 steps) |
| AppState.swift | Central state management |
| GuestsView.swift | Guest list + code generation |
| DashboardView.swift | Quick stats + actions |
| BudgetView.swift | Budget categories + editing |

## How to Add New Features

### Adding a New Tab
1. Create view in `UIComponents/`
2. Add to `HomeNavigationView` in ContentView.swift
3. Add to TabView with icon and label

### Adding to Guest RSVP
1. Update `RSVPFormView` in ContentView.swift
2. Add state variables for new fields
3. Update `GuestRSVP` model in Models.swift
4. Update `submitGuestRSVP()` in AppState.swift

### Adding to Host Dashboard
1. Update `DashboardView.swift`
2. Add new cards or sections
3. Use `@State` for local data
4. Use `StorageManager` for persistence

## Data Flow

```
Onboarding
    ↓ (sets weddingDetails)
AppState.weddingDetails
    ↓ (used by all views)
GuestsView, BudgetView, etc.
    ↓ (save/load via)
StorageManager
    ↓ (JSON files in documents folder)
```

## Adding Invitation Code System

Current implementation:
- Hosts generate code from Guests tab
- Code is sent to guest via iMessage/Email
- Guest enters code in app to RSVP

To enhance:
1. Add "Generate Guest Code" button to each guest row
2. Code is saved in `invitation_codes.json`
3. Guest enters code in onboarding invite step
4. App stores code in `UserDefaults` for persistence
