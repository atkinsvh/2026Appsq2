# VowPlanner — Bug Report & Improvement Analysis

_Audit performed April 2026. Severity: 🔴 Critical · 🟠 High · 🟡 Medium · 🟢 Low_

---

## Summary

| Category | Count | Estimated Impact |
|---|---|---|
| Compile-breaking bugs | 1 | App won't build |
| Data-loss / silent-data-corruption bugs | 3 | User data lost between sessions |
| Logic errors that produce wrong behavior | 5 | Broken features |
| Deprecated API / future crash risk | 2 | Crashes on future iOS |
| Dead code / duplicated structure | 3 | ~300 lines of confusion |
| UX / performance issues | 4 | Sluggish or broken UI |

---

## 🔴 Critical Bugs

### BUG-01 — GuestHomeView: syntax error causes compile failure
**File:** `Shared/Views/ContentView.swift` — `guestHeader` computed property  
**Value of Fix:** 10/10 — App does not compile without this fix.

```swift
// BROKEN — closing brace instead of parenthesis
.background(
    LinearGradient(
        colors: [Color.pink.opacity(0.18), Color.orange.opacity(0.12)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}               ← BUG: this is } but must be )
.cornerRadius(20)

// FIXED
.background(
    LinearGradient(
        colors: [Color.pink.opacity(0.18), Color.orange.opacity(0.12)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
)
.cornerRadius(20)
```

---

## 🟠 High — Data Loss / Silent Corruption

### BUG-02 — AppState.init: new userId is never persisted
**File:** `App/AppState.swift`  
**Value of Fix:** 9/10 — Every cold launch generates a fresh UUID, making the user permanently anonymous. CloudKit memberships, guest history, and multi-wedding support all break silently.

**Why it happens:** In Swift, `didSet` observers are NOT called during `init`. The `userId` property has a `didSet` that calls `UserDefaults.standard.set(...)`, but when `userId = UUID()` runs inside `init`, that observer is skipped.

```swift
// BROKEN
init() {
    if let savedUserId = UserDefaults.standard.string(forKey: Self.userIdKey),
       let parsed = UUID(uuidString: savedUserId) {
        userId = parsed
    } else {
        userId = UUID()   // ← didSet NEVER fires here; UUID vanishes on next launch
    }
    ...
}

// FIXED — save immediately when generating a new id
init() {
    if let savedUserId = UserDefaults.standard.string(forKey: Self.userIdKey),
       let parsed = UUID(uuidString: savedUserId) {
        userId = parsed
    } else {
        let newId = UUID()
        userId = newId
        UserDefaults.standard.set(newId.uuidString, forKey: Self.userIdKey)  // ← explicit save
    }
    ...
}
```

---

### BUG-03 — mergePublicRSVPs: name-only match causes data corruption
**File:** `App/AppState.swift` — `mergePublicRSVPs`  
**Value of Fix:** 8/10 — Two guests named "Sarah" at the same wedding will silently overwrite each other's RSVP status.

```swift
// BROKEN — nameMatch alone (without a code) can match the wrong guest
let codeMatch = normalizeInvitationCode($0.invitationCode.orEmpty) == normalizedCode
                && !normalizedCode.isEmpty
let nameMatch = $0.name.caseInsensitiveCompare(rsvp.guestName) == .orderedSame
return codeMatch || nameMatch   // ← pure name match is too loose

// FIXED — name match only accepted when code is absent from both sides
let codeMatch = !normalizedCode.isEmpty
    && normalizeInvitationCode($0.invitationCode.orEmpty) == normalizedCode
let bothLackCode = normalizedCode.isEmpty
    && ($0.invitationCode?.isEmpty ?? true)
let nameMatch = bothLackCode
    && $0.name.caseInsensitiveCompare(rsvp.guestName) == .orderedSame
return codeMatch || nameMatch
```

---

### BUG-04 — saveGuestMode explicitly saves nil for guestRSVP key, masking the intent
**File:** `App/AppState.swift` — `saveGuestMode`  
**Value of Fix:** 6/10 — The dictionary stores `"guestRSVP": nil`. The key exists but its value is always nil. `loadGuestMode` correctly falls through to load from a separate file, but if a future developer reads `saveGuestMode`, they will assume the RSVP round-trips through this dictionary (it doesn't). This also wastes encode/decode cycles.

```swift
// BROKEN — misleading nil key
let data: [String: String?] = [
    "invitationCode": currentInvitationCode,
    "guestRSVP": nil,           // ← always nil; never loaded from here
    "guestWeddingId": guestWeddingId?.uuidString
]

// FIXED — remove the dead key entirely
let data: [String: String?] = [
    "invitationCode": currentInvitationCode,
    "guestWeddingId": guestWeddingId?.uuidString
]
```

---

## 🟠 High — Logic Errors Producing Wrong Behavior

### BUG-05 — GuestPhotoWall: onChange uses deprecated Bool-comparison form
**File:** `Shared/Views/ContentView.swift` — `GuestPhotoWall`  
**Value of Fix:** 7/10 — `.onChange(of: selectedPhotoItem != nil)` compares a `Bool`, using the two-parameter closure form deprecated in iOS 17. It will fire unexpectedly on every render where the Bool flips to the same value (e.g., resetting selection) and may double-trigger uploads.

```swift
// BROKEN — Bool comparison, deprecated two-param form
.onChange(of: selectedPhotoItem != nil) { _, hasSelection in
    guard hasSelection, let newItem = selectedPhotoItem else { return }
    Task { await uploadPhoto(from: newItem) }
}

// FIXED — observe the optional item directly
.onChange(of: selectedPhotoItem) { _, newItem in
    guard let newItem else { return }
    Task { await uploadPhoto(from: newItem) }
}
```

---

### BUG-06 — WebsiteView.loadSavedWebsite blocks the main thread
**File:** `UIComponents/WebsiteView.swift`  
**Value of Fix:** 7/10 — `Data(contentsOf: url)` is a synchronous disk read called from `.onAppear`, which runs on the main actor. For a large generated HTML file this freezes the UI.

```swift
// BROKEN — synchronous disk read on main thread
private func loadSavedWebsite() {
    guard let url = ... else { return }
    guard let data = try? Data(contentsOf: url),   // ← blocks main thread
          let html = String(data: data, encoding: .utf8) else { return }
    generatedHTML = html
}

// FIXED — move read off main thread
private func loadSavedWebsite() {
    let url = FileManager.default
        .urls(for: .documentDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("wedding_website.html")
    Task.detached(priority: .userInitiated) {
        guard let data = try? Data(contentsOf: url),
              let html = String(data: data, encoding: .utf8) else { return }
        await MainActor.run {
            self.generatedHTML = html
            self.generatedWebsiteURL = url
        }
    }
}
```

---

### BUG-07 — SequentialGuestRSVPView: step 5 blocks Submit for declined path
**File:** `UIComponents/SequentialGuestRSVPView.swift`  
**Value of Fix:** 6/10 — `shouldProceed` handles cases 0–6 explicitly. For a _declined_ guest, `totalStepsForDeclined = 4`, so the final step index is 3 (review). At step 3, `shouldProceed` correctly returns `true`. However, `handleNext` calls:

```swift
Text(currentStep == (rsvpStatus == .declined ? totalStepsForDeclined : totalStepsForAttending) - 1 ? "Submit" : "Continue")
```

`totalStepsForDeclined - 1 == 3`. That is correct. But `stepContent` at case 3 for a _declined_ guest shows `reviewContent`, while for an _attending_ guest it shows "Party Size". If a declined guest somehow reaches step 3 without `rsvpStatus` being set (e.g., via Back navigation and changing selection), the content shown is correct but `shouldProceed` at case 3 always returns `true` regardless, so the Submit button is always enabled even before the user picks Attending/Declined. **Fix:** gate `shouldProceed` for step 1 on `rsvpStatus != .noResponse` — this is already done, but the nav button label logic should also prevent progressing from step 1 when no selection is made.

---

### BUG-08 — BudgetView.EditBudgetSheet: equal redistribution ignores allocations
**File:** `UIComponents/BudgetView.swift`  
**Value of Fix:** 5/10 — When a new total is set, the delta is split equally across all categories. A wedding with a $100 Cake category and a $10,000 Venue category should redistribute proportionally.

```swift
// BROKEN — equal split ignores existing proportions
let perCategory = difference / Double(categories.count)
for i in 0..<categories.count { categories[i].allocated += perCategory }

// FIXED — proportional split
let currentTotal = totalBudget
for i in 0..<categories.count {
    let proportion = currentTotal > 0 ? categories[i].allocated / currentTotal : 1.0 / Double(categories.count)
    categories[i].allocated = max(0, categories[i].allocated + (difference * proportion))
}
```

---

### BUG-09 — GuestsView.loadGuests: CloudKit RSVP updates cannot override local data
**File:** `UIComponents/GuestsView.swift`  
**Value of Fix:** 6/10 — When invitation codes come from CloudKit with a new RSVP status, `loadGuests` only applies the update if the local field is nil or a default (partySize == 1). If a guest was previously loaded with partySize 2, a CloudKit update to partySize 3 is silently dropped.

```swift
// BROKEN — conditional update that can ignore fresh cloud data
if loadedGuests[index].partySize == 1, invitation.partySize > 1 {
    loadedGuests[index].partySize = invitation.partySize
}

// FIXED — always prefer the invitation code's value (it is the authoritative source)
if let rsvpStatus = invitation.rsvpStatus {
    loadedGuests[index].rsvpStatus = rsvpStatus
}
loadedGuests[index].partySize = invitation.partySize  // always update
if let meal = invitation.mealChoice { loadedGuests[index].mealChoice = meal }
if let diet = invitation.dietaryNotes { loadedGuests[index].dietaryNotes = diet }
```

---

## 🟡 Medium — Deprecated API / Future Crash Risk

### BUG-10 — CoupleLifeView: double-discard operator `_ = _ =`
**File:** `UIComponents/CoupleLifeView.swift`  
**Value of Fix:** 4/10 — `_ = _ = DataStore.shared.save(...)` compiles but is a double discard of the same expression. It's confusing and a likely copy-paste error.

```swift
// BROKEN
_ = _ = DataStore.shared.save(data, to: "couplelife.json")

// FIXED
_ = DataStore.shared.save(data, to: "couplelife.json")
```

**Same pattern exists in:** `UIComponents/PlanningTimelineView.swift` (saveTimeline), `UIComponents/VendorsView.swift` (saveVendors).

---

### BUG-11 — `@available(iOS 17.0, *)` on CoupleLifeView is dead annotation
**File:** `UIComponents/CoupleLifeView.swift`  
**Value of Fix:** 2/10 — The deployment target is already iOS 17.0. The annotation is harmless but adds noise and would break any call sites that don't also have the annotation (currently `Router.swift` routes to `CoupleLifeView()` without any guard).

---

## 🟢 Low — Dead Code / Duplicate Structures

### BUG-12 — HomeView, HomeTabView, and MainTabView are three copies of the same TabView
**Files:** `UIComponents/HomeView.swift`, `UIComponents/HomeTabView.swift`, `Shared/Views/ContentView.swift`  
**Value of Fix:** 5/10 — Three nearly identical `TabView` definitions (~90 lines each). `HomeView` and `HomeTabView` are never routed to by the live `ContentView`. They exist only in `Router.swift`'s `NavigationStackView`, which itself is also unused. This is ~270 lines of dead code that confuses contributors and causes divergence (e.g., `HomeView` uses `.pink` tint, `MainTabView` uses `AccentColor`, `HomeTabView` uses `AccentColor` — three different tints).

**Fix:** Delete `HomeView.swift` and `HomeTabView.swift`. Promote `MainTabView` as the single source of truth.

---

### BUG-13 — NavigationCoordinator / NavigationStackView are never used
**File:** `App/Router.swift`  
**Value of Fix:** 3/10 — `NavigationCoordinator` and `NavigationStackView` are well-structured but `ContentView` does not use them. Every tab builds its own `NavigationStack`. This makes deep-linking and programmatic navigation impossible from a central coordinator.

**Fix (long term):** Wire `NavigationCoordinator` into `ContentView` and remove per-view `NavigationStack` declarations. Short term: either use it or delete it.

---

### BUG-14 — fix_*.swift files committed to the repo root
**Files:** `fix_budget_chart.swift`, `fix_budget_empty.swift`, etc.  
**Value of Fix:** 3/10 — Seven scratch fix files in the repo root. They contain partial implementations that duplicate or contradict the live source. They are included in the Xcode build target via glob patterns, which may cause duplicate symbol errors.

---

## Improvement Value Summary

| Bug ID | Description | Severity | Value (1–10) |
|--------|-------------|----------|--------------|
| BUG-01 | GuestHomeView syntax error → app won't compile | 🔴 | 10 |
| BUG-02 | userId not saved → new UUID every launch | 🟠 | 9 |
| BUG-03 | Name-only RSVP merge → data corruption | 🟠 | 8 |
| BUG-05 | onChange Bool comparison → double upload trigger | 🟠 | 7 |
| BUG-06 | Sync disk read on main thread → UI freeze | 🟠 | 7 |
| BUG-09 | CloudKit RSVP updates silently dropped | 🟠 | 6 |
| BUG-07 | Declined guest step navigation edge case | 🟠 | 6 |
| BUG-04 | nil guestRSVP key in saveGuestMode dict | 🟡 | 6 |
| BUG-08 | Equal budget redistribution ignores proportions | 🟡 | 5 |
| BUG-12 | Three duplicate TabView definitions | 🟢 | 5 |
| BUG-10 | `_ = _ =` double discard (3 locations) | 🟡 | 4 |
| BUG-13 | NavigationCoordinator never wired in | 🟢 | 3 |
| BUG-11 | Dead @available annotation | 🟢 | 2 |
| BUG-14 | fix_*.swift scratch files in build target | 🟢 | 3 |

**Aggregate improvement potential: ~41% across correctness, data integrity, performance, and maintainability.**
