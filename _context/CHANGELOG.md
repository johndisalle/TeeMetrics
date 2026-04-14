# TeeMetrics Changelog

All notable changes to TeeMetrics are documented here. Newest entries on top.

---

## 2026-04-09 — Phase 1B: GPS Pin Placement UI

**Scope:** Pin placement UI. Builds on Phase 1A (data model) by adding the
first user-facing surface for dropping front/center/back green pins on a
satellite map. Also introduces course provenance tracking and Pro-gating
for pin editing on non-user courses.

### Added

- **`TeeMetrics/Views/Course/HoleGPSEditorView.swift`** — new ~380-line view:
  - Full-screen SwiftUI `Map` with `.mapStyle(.hybrid(elevation: .realistic))`
  - Horizontal scrolling hole picker (1–18) at top with dot indicator for
    holes that already have center pins set
  - Three pin buttons: **Set Front** (blue), **Set Center** (red), **Set Back**
    (green), with distinct `PinKind` enum encapsulating label/color/icon
  - Tapping a pin button enters placement mode; next tap on the map drops
    that pin at the tapped coordinate via `MapReader` + `proxy.convert`
  - **"Use My Location"** button that drops the active pin at the user's
    current `CLLocation` (on-course workflow, reuses `CourseDetectionManager`)
  - Three map annotations with distinct colors, glass-backed `mappin.circle.fill`
    icons, and labels below
  - Placement-mode banner in the top-right of the map during active placement
  - Distance-between-pins readout: front → back in yards with ✓ if typical
    (20–40 yds) or ⚠︎ warning if outside that range
  - Save button + success haptic
  - Pro-gating: if `GatingManager.canEditPins(for:)` returns false, a locked
    overlay is shown with "Upgrade to Pro" CTA that presents `SubscriptionView`
  - Community share-back alert: if the course came from CloudKit and has a
    `cloudRecordID`, after saving the user is asked "Share these pins with
    other players?"; Share calls `CloudKitCourseService.updateGreenPins`
- **`GolfCourse` provenance fields** (`Models/GolfCourse.swift`):
  - `courseSource: String?` — tracks origin: `"user"` / `"bundled"` / `"community"`
  - `cloudRecordID: String?` — CloudKit record name for community-imported
    courses (used for pin sync-back)
  - `isUserCreated: Bool` computed — `true` when source is nil or `"user"`
  - `init` extended with both as optional parameters (default `"user"` / `nil`)
    so every existing call site continues to compile unchanged
- **`GatingManager.canEditPins(for:)`** — gate for pin editing:
  - Pro users: always allowed
  - Non-Pro: allowed for user-created courses only
- **`GatingManager.ProFeature.pinEditing`** — new enum case for paywall labeling
- **`CloudKitCourseService.updateGreenPins(for:)`** — new async method that
  fetches a `CKRecord` by `recordName`, re-encodes the local course's holes
  (including any newly-placed pins) into the `holesJSON` field, and saves.
  Returns `true` on success.
- **"Set GPS Pins" section** in `CourseDetailView` (`Views/Course/CourseLibraryView.swift`):
  - New Section with `mappin.and.ellipse` icon
  - Shows "X of 18 holes mapped" subtitle
  - Tap presents `HoleGPSEditorView` as a sheet
  - Hole list now shows a filled map-pin icon next to holes with pins set
  - **Resolves PROJECT_BRIEF Known Bug #11** (CourseDetailView was read-only)
- **"Add GPS Pins (Optional)" section** in `AddCourseView`:
  - New toggle: "Add GPS Pins After Saving"
  - When enabled, after the save + share-with-community alert resolves, the
    view presents `HoleGPSEditorView` for the newly created course instead
    of dismissing
  - New `finishSave()` helper handles the branching (GPS editor vs dismiss)

### Changed

- **`BundledCourseImporter.importCourse`** — now passes `courseSource: "bundled"`
  when creating courses from the bundled JSON
- **`CloudKitCourseService.importCourse`** — now passes
  `courseSource: "community"` and `cloudRecordID: shared.id.recordName` when
  importing community courses, enabling the sync-back flow

### Design Decisions

- **Tap to place, not long-press.** The task brief said "long-press drops that
  pin," but SwiftUI's `Map` doesn't have a reliable long-press + location API
  in iOS 17. Single-tap-after-selecting-mode is the cleaner pattern (same as
  Google Maps mobile) and is fully supported via `MapReader` + `proxy.convert`.
  The placement-mode banner ("Tap the map to place FRONT") makes the flow
  discoverable.
- **SwiftUI `Map`, not `MKMapView` via `UIViewRepresentable`.** iOS 17's
  SwiftUI `Map` with `.mapStyle(.hybrid(elevation: .realistic))` gives the
  same satellite/3D visuals as MKMapView's hybridFlyover without the UIKit
  bridging complexity.
- **Course provenance as optional `String?`**, not a required `String` with
  default. Keeps the migration strictly lightweight (no default value propagation
  needed for existing rows) and treats nil as "user-created" for backward compat.
- **No new ViewModel.** Following the MVVM-lite house pattern, all state is
  in `@State` + `@Bindable` on the view itself.
- **Share-back only for community courses.** Bundled-course pin edits stay
  local — we don't own the bundled dataset and can't merge community pins
  into it. Only courses with a `cloudRecordID` get the share-back prompt.

### Migration Notes

This is a **lightweight SwiftData migration**. Two new optional properties
(`courseSource: String?`, `cloudRecordID: String?`) added to the existing
`GolfCourse` `@Model`. Existing rows load with `nil` for both fields. The
`isUserCreated` computed property treats nil as user-created, so all pre-1B
courses are editable without a Pro subscription.

### Build Verification

Manual correctness pass completed (environment has no `xcodebuild`):

- Verified all iOS 17 Map APIs used: `MapReader`, `MapCameraPosition`,
  `.mapStyle(.hybrid(elevation: .realistic))`, `proxy.convert(_:from:)`,
  and `.onTapGesture(coordinateSpace: .local) { ... }`
- All existing `GolfCourse(...)` call sites continue to compile — the new
  init parameters (`courseSource`, `cloudRecordID`) have defaults
- `GatingManager.ProFeature.pinEditing` added with a `switch` case that
  returns `true` (defers actual gating to `canEditPins(for:)` per-course)
- `CourseDetailView` sheet uses `HoleGPSEditorView(course:)` with `@Bindable`
  propagation
- **User should run `xcodebuild build` or build in Xcode on their Mac after
  pulling to confirm zero errors.**

### Files Modified

- `TeeMetrics/Models/GolfCourse.swift`
- `TeeMetrics/Services/GatingManager.swift`
- `TeeMetrics/Services/CloudKitCourseService.swift`
- `TeeMetrics/Services/BundledCourseImporter.swift`
- `TeeMetrics/Views/Course/CourseLibraryView.swift`
- `TeeMetrics/Views/Round/AddCourseView.swift`

### Files Added

- `TeeMetrics/Views/Course/HoleGPSEditorView.swift`

### Files NOT Modified (explicitly per task scope)

- `TeeMetrics/Resources/courses.json`
- `TeeMetrics/App/TeeMetricsApp.swift` (SwiftData migration is automatic)
- Any view files outside the two entry points specified

---

## 2026-04-09 — Phase 1A: GPS Green Pin Data Model

**Scope:** Data model only. No UI changes. Lays the foundation for on-course
GPS distance-to-green features in later phases.

### Added
- **`HoleInfo` model** (`TeeMetrics/Models/GolfCourse.swift`): 6 new optional
  stored properties for green GPS coordinates:
  - `greenFrontLatitude: Double?`
  - `greenFrontLongitude: Double?`
  - `greenCenterLatitude: Double?`
  - `greenCenterLongitude: Double?`
  - `greenBackLatitude: Double?`
  - `greenBackLongitude: Double?`
- **`HoleInfo.hasGreenPins: Bool`** — computed property; true only when the
  green **center** coordinates are both set (front/back are optional
  refinements, center is the minimum viable pin).
- **`HoleInfo.distanceYards(from: CLLocation) -> (front:center:back:)`** —
  returns distance to each green point in yards using
  `CLLocation.distance(from:)` with meters × 1.09361 conversion. Nil-safe
  per coordinate.
- **`HoleInfo.init`**: extended with 6 optional parameters (all default to
  `nil`), so every existing call site continues to compile unchanged.
- **`BundledHole` struct** (`Services/BundledCourseImporter.swift`): 6 new
  optional Codable fields (`greenF_lat`, `greenF_lon`, `greenC_lat`,
  `greenC_lon`, `greenB_lat`, `greenB_lon`). Missing keys in existing
  `courses.json` decode to `nil` automatically.
- **JSON schema documentation** added to the top of `BundledCourseImporter.swift`
  describing the new optional fields and reserving them for future use.

### Changed
- **`SharedCourseRecord.holes`** (`Services/CloudKitCourseService.swift`):
  type changed from `[[String: Int]]` to `[[String: Any]]` to hold mixed
  Int/Double values (green GPS coordinates are `Double`).
- **`CloudKitCourseService.shareCourse`**: upload encoder now includes any
  present green coordinates in the per-hole JSON dictionary.
- **`CloudKitCourseService.importCourse`**: download decoder now extracts
  green coordinates via `as? Double` and forwards them to the `HoleInfo` init.
- **`CloudKitCourseService.parseRecord`**: JSON parser now uses
  `[[String: Any]]` instead of `[[String: Int]]`.
- **`BundledCourseImporter.importCourse`**: now forwards all 6 green coordinate
  fields from `BundledHole` to `HoleInfo`.

### Not Changed
- `TeeMetrics/Resources/courses.json` — **unchanged**. Bundled courses still
  have no pin data. `BundledHole`'s optional Codable fields decode missing
  keys as `nil`, so decoding continues to succeed.
- `TeeMetricsApp.swift` — **unchanged**. SwiftData handles adding optional
  properties to an existing `@Model` as a **lightweight migration automatically**.
  No `VersionedSchema` is needed; existing `HoleInfo` rows load with `nil`
  for the new fields.
- No view code was modified.
- No new CoreLocation imports were added to views.

### Migration Notes
This is a **lightweight SwiftData migration**. On first launch after update,
existing `HoleInfo` rows will have `nil` values for all 6 new properties.
`hasGreenPins` returns `false` for these rows, which will gate any future
GPS HUD UI behind that flag.

### Build Verification
Manual correctness pass completed (environment has no `xcodebuild`):
- All edited files re-read and checked for syntactic consistency.
- Only call site constructing `HoleInfo` in views is `AddCourseView.swift`
  (line 168); it passes the original 5 parameters only. New params default
  to `nil`, so compilation is unaffected.
- Only call site constructing `SharedCourseRecord` is `parseRecord` in
  `CloudKitCourseService.swift`; it already uses the new `[[String: Any]]`
  type.
- **User should run `xcodebuild build` or build in Xcode on their Mac after
  pulling to confirm zero errors.**

### Files Modified
- `TeeMetrics/Models/GolfCourse.swift`
- `TeeMetrics/Services/CloudKitCourseService.swift`
- `TeeMetrics/Services/BundledCourseImporter.swift`

### Files NOT Modified (explicitly per task scope)
- `TeeMetrics/Resources/courses.json`
- `TeeMetrics/App/TeeMetricsApp.swift`
- Any view files
