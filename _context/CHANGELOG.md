# TeeMetrics Changelog

All notable changes to TeeMetrics are documented here. Newest entries on top.

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
