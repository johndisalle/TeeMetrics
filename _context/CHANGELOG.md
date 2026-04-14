# TeeMetrics Changelog

All notable changes to TeeMetrics are documented here. Newest entries on top.

---

## 2026-04-14 — Phase 2: Multi-tee schema + per-tee scorecards

**Scope:** Upgrade the course/round schema so the app can model multiple
tee boxes per course (Blue, White, Gold, Red, etc.) with independent
par/yardage/slope/rating, let the golfer pick which tee they played
each round, and feed the correct per-tee rating/slope into the handicap
calculator.

### Environment note

The task brief describes a `tools/api_cache/` directory with cached
GolfCourseAPI responses that `tools/migrate_tees.py` should read from.
**Those cache files are not committed to the repo** — they live on the
original machine that ran the GolfCourseAPI rebuild. The migration
script is written and committed, but it must be run on the machine
that has the cache. This sandbox environment has no cache and no API
access, so the data-side half of Phase 2 is deferred to the user.

All Swift schema and UI changes are additive and backward-compatible:
if `courses.json` has no `tees` array (legacy / pre-migration /
unmatched), the tee picker is hidden and the app falls back to the
existing default scorecard on `HoleInfo`.

### Added

- **`tools/migrate_tees.py`** — one-shot migration script (~200 LOC):
  - Reads `tools/api_cache_index.json` and
    `tools/api_cache/<course_id>.json` — no network calls
  - For each course in `TeeMetrics/Resources/courses.json`, looks up
    the cached API response, extracts `tees.male` and `tees.female`,
    and writes a flattened `"tees"` array with our schema:
    `name`, `gender`, `par`, `yardage`, `slope`, `rating`, `holes`
  - Keeps the existing top-level `par / yardage / slope / rating /
    holes` fields intact — the new `tees` array is additive
  - Unmatched courses get `"tees": []`
  - Backs up `courses.json` to `courses.json.tees-YYYYMMDD-HHMMSS.bak`
    before writing
  - Prints a summary: matched / unmatched / cache-missing / empty
  - Pre-flight checks surface a clean error when the cache is missing
    instead of crashing
- **`TeeMetrics/Models/CourseTee.swift`** (new file, 2 new SwiftData
  models):
  - `@Model CourseTee` — `name`, `gender`, `par`, `yardage`, `slope`,
    `rating` + `course: GolfCourse?` back-ref + cascading `holes:
    [TeeHole]` relationship. Helper `hole(number:)` for lookup.
  - `@Model TeeHole` — `num`, `par`, `yardage`, `handicap` + `tee:
    CourseTee?` back-ref. Per-hole row because par/yardage varies
    per tee box even though the green location is shared.
- **`GolfCourse.tees: [CourseTee]`** — new cascading relationship.
  `course.tee(named:)` helper for name-based lookup.
- **`GolfRound.teeName: String?`** — optional (so pre-Phase-2 rounds
  migrate cleanly). When set, `selectedTee` resolves the matching
  `CourseTee` on the course and `effectivePar` prefers the tee's par.
- **`GolfRound.selectedTee`**, **`effectivePar`** — new computed
  properties. `scoreToPar` now uses `effectivePar` so every existing
  call site (dashboard, history, celebration, round card, PDF,
  comparison) picks up tee-aware math automatically.
- **`GolfRound.init(teeName:)`** — new labeled parameter defaulted to
  `nil`. Existing call sites (`NewRoundView`, `SampleDataSeeder`) use
  labeled args and compile unchanged.
- **`TeeMetricsApp` schema array** — now registers `CourseTee.self`
  and `TeeHole.self` in the SwiftData `Schema([...])`.
- **`BundledCourseImporter`** — new `BundledTee` / `BundledTeeHole`
  Codable structs. On import, if the course has a `tees` array, each
  tee becomes a `CourseTee` with 18 `TeeHole` children.
  `BundledCourse.tees` is optional so files without the new field
  still decode.
- **`NewRoundView` tee picker**:
  - Shown only when the selected course has at least one `CourseTee`
  - `Picker` lists all tees sorted back-to-short, labeled
    `"Blue · 6832y"`
  - Selection row shows `"Par 72 · Slope 138 · Rating 73.5"` for the
    chosen tee
  - `onChange(of: selectedCourse)` resets the tee to the
    middle-by-yardage default whenever the course changes
  - `startRound()` writes `selectedTeeName` to `round.teeName` and
    uses the tee's per-hole par when pre-populating `HoleEntry` rows
- **`HoleLoggerView`**:
  - New `selectedTeeHole` computed (`entry.round?.selectedTee?.hole
    (number:)`) and `displayYardage` that prefers the tee-specific
    yardage over `HoleInfo`'s default
  - Hole header now shows `"Par 4 · 426 yds · Blue"` when a tee is
    selected
- **`RoundDetailView`** — header now shows `"{teeName} tees"` in
  `Theme.primary` under the course name when `round.teeName` is set.
- **`StatsCalculator.handicapIndex`** — when a round has a
  `selectedTee`, uses the tee's `rating` and `slope` for the
  differential calculation instead of the course's defaults. Falls
  back to the course's `courseRating` / `slopeRating` for legacy
  rounds or when the tee isn't found. Adds a guard against `slope == 0`.

### Not Changed (intentional)

- **`HoleGPSEditorView` and all green-pin logic** are untouched. Pins
  live on `HoleInfo` and are tee-agnostic — the green is the green
  regardless of which box you tee off from.
- **`courses.json`** is not modified in this commit. The migration
  script must be run locally on the machine with the `tools/api_cache/`
  directory.

### Migration Notes

This is a mixed migration:

1. **SwiftData** — two new `@Model` types (`CourseTee`, `TeeHole`) and
   one new optional property (`GolfRound.teeName`). SwiftData handles
   this as a lightweight migration automatically. No `VersionedSchema`
   is required.

2. **courses.json** — additive `tees` array. Existing `par / yardage /
   slope / rating / holes` fields remain untouched so decoding continues
   to work for courses without the new field. To populate the new
   field:
   ```
   python3 tools/migrate_tees.py
   git add TeeMetrics/TeeMetrics/Resources/courses.json
   git commit -m "data: Populate multi-tee scorecards from API cache"
   ```
   Must be run on the machine with `tools/api_cache/` present.

### Build Verification

Attempted `xcodebuild` — not available in this sandbox environment
(Linux container). Manual checks:

- Brace balance on all 9 modified/created Swift files (all balanced)
- All `GolfRound(...)` call sites use labeled parameters; new
  `teeName` parameter has a `nil` default so `NewRoundView` and
  `SampleDataSeeder` compile unchanged
- All `scoreToPar` call sites (dashboard, history, celebration, round
  card, PDF, comparison views) reach `GolfRound.scoreToPar` which now
  reads from `effectivePar` — tee-awareness flows through transparently
- `python3 tools/migrate_tees.py` runs and fails cleanly with a
  helpful error about the missing cache, as expected in this
  environment

**User must run xcodebuild / Xcode build on their Mac to confirm
zero compiler errors.**

### Files Added

- `tools/migrate_tees.py`
- `TeeMetrics/TeeMetrics/Models/CourseTee.swift`

### Files Modified

- `TeeMetrics/TeeMetrics/Models/GolfCourse.swift`
- `TeeMetrics/TeeMetrics/Models/GolfRound.swift`
- `TeeMetrics/TeeMetrics/App/TeeMetricsApp.swift`
- `TeeMetrics/TeeMetrics/Services/BundledCourseImporter.swift`
- `TeeMetrics/TeeMetrics/Services/StatsCalculator.swift`
- `TeeMetrics/TeeMetrics/Views/Round/NewRoundView.swift`
- `TeeMetrics/TeeMetrics/Views/LiveRound/HoleLoggerView.swift`
- `TeeMetrics/TeeMetrics/Views/History/RoundDetailView.swift`

---

## 2026-04-09 — Phase 1B Fix: Center map on course coordinates

**Scope:** Bug fix + small feature extension. Addresses two issues with
`HoleGPSEditorView` from Phase 1B:
1. Map opened at `.automatic` instead of the actual course.
2. Bundled courses had city-level `lat/lng` that never got refined as
   users placed accurate pins.

### Added

- **`GolfCourse.coordinatesRefined: Bool?`** (optional, nil default) —
  guards the progressive coordinate refinement so it only runs once per
  course. Lightweight SwiftData migration: nil for all existing rows,
  which the refinement check treats as "not yet refined."
- **`GolfCourse.init`** extended with `coordinatesRefined: Bool? = nil`
  parameter. All existing call sites continue to compile unchanged via
  the default.
- **`CloudKitCourseService.updateCourseLocation(for:)`** — new async
  method that fetches a `CKRecord` by `recordName`, updates the
  `latitude` / `longitude` fields with the local course's current
  coordinates, and saves. Returns `Bool`.
- **Recenter button** (`HoleGPSEditorView`) — floating circular button
  bottom-right of the map using `location.fill` SF Symbol on an
  ultra-thin material background. Tap recenters the camera using the
  same priority order as initial appear.
- **`bestCenterCoordinate()` helper** (`HoleGPSEditorView`) — single
  source of truth for camera centering with priority order:
  - (a) First placed center pin on any hole (user returning to edit
    should see their work)
  - (b) Stored `course.latitude` / `course.longitude` if non-zero
  - (c) `CourseDetectionManager.shared.currentLocation` if available
  - (d) nil → caller falls back to `.automatic`
- **`refineCoordinatesIfNeeded()`** (`HoleGPSEditorView`) — on save,
  runs progressive refinement for bundled and community courses:
  - Only runs once per course (gated by `coordinatesRefined`)
  - Uses the earliest placed center pin across any hole as the new
    course center
  - For community courses with a valid `cloudRecordID`, also pushes
    the refined location to CloudKit via `updateCourseLocation(for:)`

### Changed

- **`centerCameraOnCourse()`** (`HoleGPSEditorView`) — now uses the
  `bestCenterCoordinate()` priority helper and `MKCoordinateSpan`
  (0.008 / 0.008, ≈1km square) instead of
  `latitudinalMeters/longitudinalMeters: 800`. Falls back to
  `.automatic` when no reasonable center is known.
- **`HoleGPSEditorView.mapView`** — layout changed from
  `ZStack(alignment: .topTrailing)` to a plain `ZStack` with two
  inner `VStack` / `HStack` overlays so the placement-mode banner can
  live in the top-right while the new Recenter button lives in the
  bottom-right, without the single alignment fighting both.
- **`savePins()`** (`HoleGPSEditorView`) — now calls
  `refineCoordinatesIfNeeded()` before the community share alert.
  Save order: persist pins (automatic via `@Bindable`) → refine
  course coords → prompt share-back → dismiss.

### Migration Notes

`coordinatesRefined: Bool?` is the third optional field added to
`GolfCourse` since Phase 1A (joining `courseSource` and `cloudRecordID`).
SwiftData handles this as a lightweight migration automatically. No
`VersionedSchema` or manual migration code is required.

### Out of Scope (Reserved for Phase 2)

Per task brief: `CLGeocoder` fallback for user-created courses that
don't have lat/lng is intentionally NOT implemented here. That feature
belongs to Phase 2.

### Build Verification

Manual correctness pass (no `xcodebuild` in this environment):

- All three modified files parse with balanced braces
  (GolfCourse.swift: 9/9, CloudKitCourseService.swift: 61/61,
  HoleGPSEditorView.swift: 116/116).
- All call sites of `GolfCourse(...)` use labeled parameters; the new
  `coordinatesRefined` param has a `nil` default, so no call site
  requires an update.
- `bestCenterCoordinate()` returns `nil` only when no pins, no stored
  course coords, and no user location exist — the `centerCameraOnCourse`
  fallback to `.automatic` matches the prior behavior for that edge.
- `refineCoordinatesIfNeeded()` is gated by `courseSource` check, so
  it's a no-op for user-created courses (preserves user intent).
- **User should run `xcodebuild build` or build in Xcode on their Mac
  after pulling to confirm zero errors.**

### Files Modified

- `TeeMetrics/Models/GolfCourse.swift`
- `TeeMetrics/Services/CloudKitCourseService.swift`
- `TeeMetrics/Views/Course/HoleGPSEditorView.swift`

### Files NOT Modified

- No other views touched
- `TeeMetricsApp.swift` unchanged (lightweight migration is automatic)
- `courses.json` unchanged

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
