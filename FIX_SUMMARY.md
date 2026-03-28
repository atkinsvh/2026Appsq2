# Flow & Architecture Alignment Summary

_Last verified on March 25, 2026._

## What was corrected

1. **Routing documentation aligned with current root logic**
   - Added explicit `ContentView` branch order covering:
     - onboarding gate
     - active guest mode
     - `isGuestAccessOnly` gate (`GuestAccessGateView`)
     - host/co-planner `MainTabView`

2. **Data layer references updated to `DataStore`**
   - Removed stale references to `StorageManager`.
   - Documented that persistence and backup behavior now lives in `Services/DataStore.swift` and is coordinated by `AppState`.

3. **Host/guest behavior aligned with `AppState` implementation**
   - Host/co-planner path now reflects `isGuestAccessOnly` + wedding sync behavior.
   - Guest path now reflects invite verification + `enterGuestMode(with:)` behavior.
   - RSVP behavior updated to match `submitGuestRSVP(_:)` local persistence + CloudKit sync + retry queue behavior.

4. **Removed obsolete extension guidance**
   - Deleted old references to non-existent identifiers (such as `HomeNavigationView`) and outdated guest flow descriptions.

## Current source of truth

- `Shared/Views/ContentView.swift`
- `App/AppState.swift`
- `Services/DataStore.swift`
- `UIComponents/OnboardingView.swift`

