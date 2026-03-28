# VowPlanner Code Flow Explanation

_Last verified on March 25, 2026._

## Current Runtime Flow

### 1. App Entry
- `VowPlannerApp` creates a single `AppState` and injects it into `ContentView`. (`App/VowPlannerApp.swift`)

### 2. Root Routing (`Shared/Views/ContentView.swift`)
The app chooses one of four top-level paths:

```swift
if !appState.onboardingCompleted {
    OnboardingView()
} else if appState.isGuestMode {
    GuestModeEntryView()
} else if appState.isGuestAccessOnly {
    GuestAccessGateView()
} else {
    MainTabView()
}
```

### 3. Host Entry Path
1. User completes onboarding as host/co-planner.
2. `onboardingCompleted = true`, `isGuestMode = false`.
3. If `isGuestAccessOnly == false`, app routes to `MainTabView`.
4. Host/co-planner data sync runs through `AppState.syncFromCloudKit()` when a host wedding ID is available.

### 4. Guest Entry Path
1. Guest enters invitation code in onboarding or `GuestAccessGateView`.
2. `AppState.verifyGuestInvitationCode(_:)` validates code via cache + CloudKit lookup.
3. `AppState.enterGuestMode(with:)` sets guest context (`isGuestMode = true`, `isGuestAccessOnly = true`, `onboardingCompleted = true`) and hydrates wedding details.
4. `GuestModeEntryView` routes to:
   - `SequentialGuestRSVPView` when RSVP is still `.noResponse`
   - `GuestHomeView` after RSVP is submitted.

### 5. RSVP Behavior (`App/AppState.swift`)
- `submitGuestRSVP(_:)` persists the guest RSVP locally, updates/creates matching guest records, updates invitation records, and attempts CloudKit sync.
- Failed guest/invitation/RSVP sync operations are queued in pending sync storage and retried.

## Data Layer (Current)

### DataStore (replaces old StorageManager references)
- Unified persistence service: `Services/DataStore.swift`.
- Handles Codable save/load, atomic writes, backups, restore-from-backup, and file metadata helpers.
- Core app files managed through `AppState` constants (e.g., `wedding_details.json`, `guests.json`, `invitation_codes.json`, `all_guest_rsvps.json`).

## Flow Diagram

```text
VowPlannerApp
  └─ ContentView
      ├─ onboardingCompleted == false → OnboardingView
      ├─ isGuestMode == true          → GuestModeEntryView
      ├─ isGuestAccessOnly == true    → GuestAccessGateView
      └─ otherwise                     → MainTabView
```

```text
Guest code verification
  GuestAccessGateView / Onboarding guest step
      ↓
AppState.verifyGuestInvitationCode
      ↓
AppState.enterGuestMode(with: invitation)
      ↓
GuestModeEntryView
  ├─ RSVP missing/noResponse → SequentialGuestRSVPView
  └─ RSVP complete           → GuestHomeView
```

## Key Files

| File | Purpose |
|------|---------|
| `Shared/Views/ContentView.swift` | Top-level routing including guest access gate |
| `App/AppState.swift` | State coordination, guest/host mode transitions, RSVP persistence/sync |
| `Services/DataStore.swift` | Local persistence + backups + recovery |
| `UIComponents/OnboardingView.swift` | Role-driven onboarding and guest/partner entry steps |
| `UIComponents/WebsiteView.swift` | Website generation UI and generated output handling |

