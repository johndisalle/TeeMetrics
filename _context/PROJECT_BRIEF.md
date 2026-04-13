# TeeMetrics — Project Brief

**Last updated:** April 2026
**App Version:** 1.0.0
**Status:** Submitted to App Store (awaiting review resubmission)
**Branch:** `claude/ios-swiftui-development-v7pEm`
**Repo:** `johndisalle/TeeMetrics`

---

## 1. What the App Does

**TeeMetrics** is an iOS app positioned as "Golf Stats Tracker & Round Analyzer" — the cleanest, most powerful golf stats logger for serious amateur and club golfers. It's a freemium app that turns every round into deep, actionable insights with zero bloat, zero sensors, and zero cloud dependency by default.

### Core Value Proposition

> "Track Every Shot. Own Your Game."

Offline-first golf scoring and analytics that rivals TheGrint, Golf Pad, and 18Birdies, but rebuilt natively in SwiftUI with a premium Apple-native feel. No hardware sensors required — all data is entered by the user and stored privately on-device.

### Primary User Flows

1. **Quick Round Logging** — Score any hole in one tap using quick-score buttons (Eagle/Birdie/Par/Bogey/Double). Track putts, penalties, fairways, GIR, sand saves, and up-and-downs.
2. **Shot-by-shot Tracking** — Optional per-shot logging with club selection, distance, lie type, and result.
3. **Stats & Analytics** — Score trends, strokes gained breakdown (off-tee/approach/short game/putting), handicap projection, round comparison, and rule-based insights.
4. **Goals & Achievements** — Set targets (break 80, lower handicap, etc.) and earn 17 achievement milestones.
5. **Social Sharing** — Post-round celebration screen with confetti for personal bests, shareable round cards (Instagram feed 4:5 and story 9:16 formats), PDF round reports.

### Target User

Serious amateur and club golfers who want deep insights without wearing a sensor. The app is designed to feel premium from the first tap — targeting the App Store's Sports and Health & Fitness categories.

### Positioning

- **Free tier**: Unlimited round logging, basic scorecard and stats for first 5 rounds, 660+ pre-loaded courses, Apple Watch scoring, 6 bag templates, post-round celebrations.
- **Pro tier** ($4.99/mo, $29.99/yr with 3-day trial, $49.99 lifetime): Advanced analytics, strokes gained, handicap projection, round comparison, club recommendations, PDF reports, shareable round cards, community course sharing.

---

## 2. Tech Stack

### Platforms & Deployment Targets

| Platform | Minimum Version | Target Device |
|----------|----------------|---------------|
| **iOS** | 17.0 | iPhone (primary) |
| **iPadOS** | 17.0 | iPad (universal) |
| **watchOS** | 10.0 | Apple Watch companion |

### Language & Frameworks

- **Swift** 5.9+ (uses Swift 6-ready concurrency — `@MainActor`, `nonisolated`, `async/await`)
- **SwiftUI** exclusively — no UIKit views except where SwiftUI bridges to system APIs (ImageRenderer, PDFKit, UIGraphicsPDFRenderer for PDF generation)
- **SwiftData** for all persistence (not CoreData, not Realm)
- **Swift Charts** for all analytics visualizations
- **WidgetKit** for Home Screen / Lock Screen widgets
- **App Intents** for Siri Shortcuts
- **StoreKit 2** for subscriptions and IAP
- **CloudKit** (public database only) for community course sharing
- **WatchConnectivity** for phone ↔ watch sync
- **CoreLocation** for course auto-detection
- **MapKit** for course location display
- **UserNotifications** for local notifications
- **PDFKit** / **UIGraphicsPDFRenderer** for PDF report generation
- **Combine** (used minimally — only in WatchConnector for `@Published`)

### Dependencies

**NONE.** TeeMetrics has zero third-party dependencies:

- No CocoaPods
- No Swift Package Manager packages
- No Carthage
- No Firebase, no RevenueCat, no Sentry, no Crashlytics, no analytics SDKs

Everything is built with Apple's first-party frameworks. This is a deliberate design decision for privacy, performance, and App Store review speed.

### Required Capabilities (Signing & Capabilities)

| Capability | Target | Purpose |
|------------|--------|---------|
| **App Groups** | Main app + Widget extension | Shared UserDefaults for widget data (`group.com.teemetrics.shared`) |
| **CloudKit** | Main app | Community course sharing (container: `iCloud.com.teemetrics.app`) |
| **In-App Purchase** | Main app | Pro subscription (StoreKit 2) |
| **Background Modes** | None currently | — |

### Bundle Identifiers

- Main app: `com.teemetrics.app.TeeMetrics`
- Widget extension: `com.teemetrics.app.TeeMetrics.TeeMetricsWidgets`
- Watch app: `com.teemetrics.app.TeeMetrics.watchkitapp`

### Info.plist Privacy Strings

Currently in `TeeMetrics/Info.plist`:

```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>TeeMetrics uses your location to find nearby courses and show your position on the course map.</string>
<key>NSMicrophoneUsageDescription</key>
<string>TeeMetrics uses the microphone for voice notes during rounds.</string>
<key>NSHealthShareUsageDescription</key>
<string>TeeMetrics can read your activity data to track calories burned during rounds.</string>
<key>NSHealthUpdateUsageDescription</key>
<string>TeeMetrics can save your golf round as a workout.</string>
```

**⚠️ App Store Review Issue:** HealthKit strings are present but HealthKit is not implemented. Apple rejected the first submission for this (Guideline 2.5.1). These strings should be **removed** before resubmission.

---

## 3. Project Architecture

### Xcode Project Structure

```
TeeMetrics/
├── TeeMetrics.xcodeproj/
├── TeeMetrics/                          ← Main iOS app target
│   ├── App/
│   │   ├── TeeMetricsApp.swift          ← @main, SwiftData ModelContainer
│   │   └── MainTabView.swift            ← 5-tab root navigation
│   ├── Models/                          ← SwiftData @Model classes
│   │   ├── Golfer.swift                 ← User profile
│   │   ├── GolfCourse.swift             ← GolfCourse + HoleInfo
│   │   ├── GolfRound.swift              ← Round w/ computed stats
│   │   ├── HoleEntry.swift              ← Per-hole scoring
│   │   ├── ShotEntry.swift              ← Shot-by-shot + LieType/ShotResult enums
│   │   ├── Club.swift                   ← Club + Bag + BagTemplate enum
│   │   ├── Goal.swift                   ← User goals with progress
│   │   └── PracticeSession.swift        ← PracticeSession + PracticeShot
│   ├── Views/                           ← All SwiftUI views
│   │   ├── Onboarding/
│   │   │   └── OnboardingView.swift     ← Also contains WelcomeWalkthroughView
│   │   ├── Dashboard/
│   │   │   └── DashboardView.swift      ← Home tab
│   │   ├── Round/
│   │   │   ├── NewRoundView.swift       ← Round setup
│   │   │   ├── AddCourseView.swift      ← Custom course editor
│   │   │   ├── PracticeView.swift       ← Practice session tracking
│   │   │   └── RoundCelebrationView.swift ← Post-round celebration + confetti
│   │   ├── LiveRound/
│   │   │   ├── LiveRoundView.swift      ← Hole pager + finish logic
│   │   │   ├── HoleLoggerView.swift     ← Per-hole scoring UI
│   │   │   └── ShotTrackerView.swift    ← Shot-by-shot logging
│   │   ├── History/
│   │   │   ├── RoundHistoryView.swift   ← Rounds tab
│   │   │   └── RoundDetailView.swift    ← Full round recap + share/PDF
│   │   ├── Stats/
│   │   │   ├── StatsView.swift          ← Stats tab w/ charts
│   │   │   ├── AchievementsView.swift   ← Achievement grid
│   │   │   ├── GoalsView.swift          ← Goal list + editor
│   │   │   └── RoundComparisonView.swift ← Overlay two rounds
│   │   ├── Bag/
│   │   │   ├── BagManagerView.swift     ← Bag tab
│   │   │   └── BagTemplatePicker.swift  ← Template selector + card
│   │   ├── Course/
│   │   │   ├── CourseLibraryView.swift  ← Saved courses + add menu
│   │   │   ├── BundledCourseBrowser.swift ← 661 pre-loaded courses
│   │   │   └── CommunityCourseBrowser.swift ← CloudKit community courses
│   │   └── Settings/
│   │       ├── SettingsView.swift       ← Settings tab
│   │       └── SubscriptionView.swift   ← Pro paywall
│   ├── Services/                        ← Business logic, no SwiftUI
│   │   ├── StatsCalculator.swift        ← Handicap, strokes gained, trends
│   │   ├── SubscriptionManager.swift    ← StoreKit 2 singleton
│   │   ├── GatingManager.swift          ← Free/Pro feature gating
│   │   ├── AchievementsManager.swift    ← 17 Achievement enum cases
│   │   ├── ClubRecommendation.swift     ← "Hit your 7-iron" engine
│   │   ├── NotificationManager.swift    ← Local notifications
│   │   ├── CourseDetection.swift        ← CoreLocation nearby courses
│   │   ├── BundledCourseImporter.swift  ← Reads courses.json
│   │   ├── CloudKitCourseService.swift  ← Community course CRUD
│   │   ├── RoundCardRenderer.swift      ← ImageRenderer → UIImage
│   │   ├── PDFReportGenerator.swift     ← UIGraphicsPDFRenderer
│   │   ├── WidgetDataWriter.swift       ← Writes to App Group UserDefaults
│   │   ├── SampleDataSeeder.swift       ← Dev-only seed data (UI hidden)
│   │   └── AppIntents.swift             ← 3 Siri intents + AppShortcutsProvider
│   ├── Extensions/                      ← Shared utilities
│   │   ├── Theme.swift                  ← Color palette + gradients
│   │   ├── Extensions.swift             ← Date, View modifiers, Haptics
│   │   ├── Constants.swift              ← AppURLs, AppConfig
│   │   └── Animations.swift             ← slideIn, bounceTap, AnimatedNumber
│   ├── Widgets/
│   │   └── TeeMetricsWidgets.swift      ← @main WidgetBundle (widget target only)
│   ├── Resources/
│   │   ├── courses.json                 ← 661 pre-loaded courses
│   │   └── Assets.xcassets/             ← AccentColor, AppIcon
│   └── Info.plist                       ← Privacy strings
├── TeeMetricsWatch Watch App/           ← watchOS target
│   ├── TeeMetricsWatchApp.swift         ← @main
│   ├── WatchRoundView.swift             ← Scoring UI + WatchConnector
│   └── Assets.xcassets/
├── TeeMetricsWidgets/                   ← Widget extension target
│   └── TeeMetricsWidgets.swift
└── docs/                                ← GitHub Pages legal docs
    ├── index.html
    ├── terms.html
    ├── privacy.html
    └── support.html
```

### Architectural Patterns

- **MVVM-lite**: Views own their state with `@State`, `@Query`, `@Bindable`. No separate ViewModel classes — business logic lives in `Services/` as `enum` namespaces with static functions.
- **Singletons via `@Observable`**: `SubscriptionManager.shared`, `GatingManager.shared`, `CourseDetectionManager.shared`, `CloudKitCourseService.shared`. All marked `@MainActor @Observable`.
- **Pure functions for stats**: `StatsCalculator` is an `enum` namespace with only static functions — no state. All handicap/strokes gained logic is pure.
- **SwiftData via `@Query` in views**: No repository pattern. Views query SwiftData directly via `@Query(sort:) private var rounds: [GolfRound]`.
- **Global ModelContainer**: Injected via `.modelContainer(sharedModelContainer)` at the `WindowGroup` level in `TeeMetricsApp.swift`. CloudKit sync is **explicitly disabled** on the SwiftData container: `ModelConfiguration(schema:, isStoredInMemoryOnly: false, cloudKitDatabase: .none)`.

### Code Stats

- **~7,800 lines** of Swift across all targets
- **8 model files** (11 `@Model` classes)
- **13 service files**
- **23 view files**
- **0 unit tests** (no test target exists yet)

---

## 4. Apple Watch Companion App

### Target Info

- **Target name:** `TeeMetricsWatch Watch App`
- **Bundle ID:** `com.teemetrics.app.TeeMetrics.watchkitapp`
- **Deployment target:** watchOS 10.0
- **Type:** Watch App for Existing iOS App (embedded in the iOS app bundle)
- **Entry point:** `TeeMetricsWatchApp.swift` (`@main`)

### What It Does

A minimalist scoring companion for the iPhone app. The Watch app supports:

1. **Standalone Quick Round mode** — Tap "Quick Round" on the Watch start screen to begin scoring 18 holes without needing the phone. Par defaults to 4 for all holes unless the phone sends course data.
2. **Companion mode** — When the phone starts a round and sends course data, the Watch auto-switches to active round mode with the correct pars.
3. **Per-hole scoring** — Vertical TabView with one page per hole (1–18). Each hole shows:
   - Hole number + par
   - Score stepper (+/- buttons, color-coded: red for birdie, green for par)
   - Putts stepper
   - Running total + to-par
   - Haptic click on every score change (`WKInterfaceDevice.current().play(.click)`)
4. **"End" button** — Finishes the round and syncs back to the phone.

### File Structure

Only 2 files:

```
TeeMetricsWatch Watch App/
├── TeeMetricsWatchApp.swift   ← 13 lines, @main, hosts WatchRoundView
└── WatchRoundView.swift       ← 209 lines, all scoring logic + WatchConnector
```

### Phone ↔ Watch Communication

Uses **WatchConnectivity** (`WCSession`), not App Groups. The `WatchConnector` class is a `WCSessionDelegate`:

```swift
final class WatchConnector: NSObject, ObservableObject, WCSessionDelegate {
    @Published var lastReceivedData: [String: Any] = [:]
    var onDataReceived: (([String: Any]) -> Void)?

    override init() {
        super.init()
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
        }
    }

    func send(_ data: [String: Any]) {
        guard WCSession.default.isReachable else { return }
        WCSession.default.sendMessage(data, replyHandler: nil)
    }
}
```

### Data Sent from Watch → Phone

On every score/putts change, the Watch sends:

```swift
connector.send([
    "scores": scores,      // [Int] of length 18
    "putts": putts,        // [Int] of length 18
    "currentHole": currentHole,
])
```

### Data Sent from Phone → Watch

The phone should send (but **currently doesn't** — see Known Bugs):

```swift
[
    "pars": [Int],         // Course par per hole
    "courseName": String,
    "isActive": Bool,
]
```

### ⚠️ Watch Sync Known Issues

1. **One-way sync is partially wired**: The Watch receives messages and parses them, but the iPhone app never calls `WCSession.default.sendMessage()`. There is **no iOS-side `WatchConnector`**. The phone-to-watch flow is effectively unimplemented.
2. **No persistence on watch**: Scores are held in `@State` arrays only. If the Watch app quits mid-round, scoring is lost.
3. **No SwiftData on watch**: The Watch has no local database. All Watch data lives in memory.
4. **No App Groups on watch**: The Watch app does not read from the shared UserDefaults container.

### watchOS Assets

The Watch app has its own `Assets.xcassets` with its own `AppIcon` (watchOS uses a different icon format than iOS).

---

## 5. Widget Extension

### Target Info

- **Target name:** `TeeMetricsWidgets` (bundle ID: `com.teemetrics.app.TeeMetrics.TeeMetricsWidgets`)
- **Type:** Widget Extension
- **Entry point:** `TeeMetricsWidgets.swift` (`@main struct TeeMetricsWidgetBundle: WidgetBundle`)
- **Deployment target:** iOS 17.0

### Widgets Registered

Only **one** widget is currently registered: `TeeMetricsLastRoundWidget`, display name "Golf Stats".

```swift
struct TeeMetricsLastRoundWidget: Widget {
    let kind = "TeeMetricsLastRound"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: RoundTimelineProvider()) { entry in
            LastRoundWidgetView(entry: entry)
        }
        .configurationDisplayName("Golf Stats")
        .description("Your latest round stats and live scoring at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular])
    }
}
```

### Supported Families

| Family | Layout |
|--------|--------|
| `.systemSmall` | Vertical card: flag icon, LIVE badge (if active), course/score/to-par/date |
| `.systemMedium` | Horizontal: big score on left, course + stats (putts, FW%, HCP) on right |
| `.accessoryRectangular` | Lock Screen: compact score + course name |

### Data Flow: App Group → UserDefaults → Widget

The widget reads from a **shared App Group UserDefaults suite**: `group.com.teemetrics.shared`.

The main app writes widget data via `WidgetDataWriter` (`TeeMetrics/Services/WidgetDataWriter.swift`). The widget reads the same keys via a **private `Keys` enum** duplicated inside `TeeMetricsWidgets.swift` (intentional to avoid cross-target dependencies).

**Shared keys** (duplicated in both `WidgetDataKeys` and private `Keys`):

```swift
static let suiteName = "group.com.teemetrics.shared"
static let lastCourseName = "widget_lastCourseName"   // String
static let lastScore = "widget_lastScore"             // Int
static let lastScoreToPar = "widget_lastScoreToPar"   // String ("+6", "E", "-2")
static let lastPutts = "widget_lastPutts"             // Int
static let lastFairway = "widget_lastFairway"         // String ("57%")
static let lastDate = "widget_lastDate"               // String
static let activeHole = "widget_activeHole"           // Int
static let activeCourseName = "widget_activeCourseName" // String
static let activeRunningScore = "widget_activeRunningScore" // Int
static let isRoundActive = "widget_isRoundActive"     // Bool
static let handicap = "widget_handicap"               // Double
static let roundCount = "widget_roundCount"           // Int
```

### Timeline Provider

`RoundTimelineProvider` is a `TimelineProvider` (not `AppIntentTimelineProvider`):

- Reloads every **5 minutes** (`.after(.now.addingTimeInterval(300))`)
- Manual reload triggered via `WidgetCenter.shared.reloadAllTimelines()` from the main app on:
  - Round finish (`WidgetDataWriter.updateLastRound`)
  - Hole changes during active round (`WidgetDataWriter.updateActiveRound`)
  - Round canceled (`WidgetDataWriter.clearActiveRound`)
  - Stats updated (`WidgetDataWriter.updateStats`)

### Widget Timeline Entry

```swift
struct RoundWidgetEntry: TimelineEntry {
    let date: Date
    let courseName: String
    let score: Int
    let scoreToPar: String
    let putts: Int
    let fairwayPct: String
    let roundDate: String
    let isActive: Bool
    let currentHole: Int
    let runningScore: Int
    let handicap: Double
    let roundCount: Int
}
```

### Capabilities Required on Widget Target

- **App Groups**: `group.com.teemetrics.shared` (must match main app)

---

## 6. Features — Fully Built

### 6.1 Onboarding

- **`OnboardingView.swift`** — First-launch experience with:
  - Deep multi-stop gradient background with floating ambient orbs
  - Animated flag icon with glow pulse
  - Name input + handicap (optional) + inline bag template picker
  - Half-sheet bag template selection (6 templates)
  - 5-stage staggered spring animations
  - Tap-to-dismiss keyboard
  - Terms/Privacy links at bottom
- **`WelcomeWalkthroughView`** (same file) — Post-signup 3-page walkthrough:
  1. "Start a Round" (green bg) — 660+ courses, quick-score
  2. "Track Your Stats" (blue bg) — trends, strokes gained
  3. "Set Goals & Earn Achievements" (gold bg) — milestones, streaks
  - Animated page dots, skip button, color background transitions

### 6.2 Round Logging

- **`NewRoundView.swift`** — Round setup: course picker, nearby course suggestion (CoreLocation), multi-player toggle, weather notes
- **`LiveRoundView.swift`** — Running score header, hole pager (TabView), hole dot navigator, Finish button with celebration
- **`HoleLoggerView.swift`** — Per-hole scoring:
  - **Quick-score buttons**: Eagle / Birdie / Par / Bogey / Double (one-tap scoring)
  - "Other Score..." expands detailed +/- stepper
  - Putts and penalties steppers (always visible)
  - Toggle row: FW, GIR, Sand, U&D
  - Club recommendation tip (bulb icon)
  - Shot tracker button
  - Hole notes field
- **`ShotTrackerView.swift`** — Shot-by-shot logging: horizontal club selector, distance, lie type picker, result picker, shot list with swipe-to-delete
- **`AddCourseView.swift`** — Custom course editor: name/city/state, slope/rating, MapKit pin display, hole-by-hole par/yardage editor, "Standard Par 72 Layout" quick-fill
- **`PracticeView.swift`** — Range/putting/chipping session logging with club + distance tracking

### 6.3 Dashboard (Home Tab)

- **`DashboardView.swift`** — Home screen:
  - Welcome header with time-of-day greeting + handicap
  - Streak banner (`🔥` flame icon + "5-week streak!")
  - Quick Start / Resume Round button (green gradient card)
  - Stats grid (4 cards: Avg Score, Fairways, GIR, Avg Putts)
  - Recent rounds list (last 5, with "See All" link)
  - Highlights section (trends, personal best, rounds logged)
  - Handicap projection card
  - Quick links grid (Goals, Achievements, Practice)
  - Free rounds remaining card (non-Pro users)
  - Pro upgrade banner
  - Staggered slide-in animations via `.slideIn(delay:)`

### 6.4 Round History (Rounds Tab)

- **`RoundHistoryView.swift`** — Searchable list with stats header (Rounds, Best, Avg), score-badge rows
- **`RoundDetailView.swift`** — Full recap:
  - Score summary with front/back 9, putts, FW%, GIR%
  - Strokes gained breakdown (Pro)
  - Scorecard grid (front 9 / back 9)
  - Hole-by-hole detail rows
  - Notes
  - **Share Round Card** button (opens `RoundShareSheet` with feed/story format picker)
  - **Export PDF Report** button (pro-gated)

### 6.5 Stats Dashboard (Stats Tab)

- **`StatsView.swift`** — Stats tab with Swift Charts:
  - Overview cards (Rounds, Best, Handicap)
  - Score trend line chart (last 20 rounds + par reference line)
  - Putts per round bar chart
  - Fairway % + GIR % dual-line chart
  - Strokes gained bar chart (Pro-gated)
  - Handicap progress chart (Pro-gated)
  - Rule-based insights cards
  - Links to Compare Rounds, Achievements, Goals
- **`RoundComparisonView.swift`** — Overlay two rounds: hole-by-hole line chart with two series, stat comparison table with winner highlighting
- **`AchievementsView.swift`** — Grid of 17 achievements with earned/locked states, circular progress indicator
- **`GoalsView.swift`** — Active/completed goal list with progress bars, goal editor sheet

### 6.6 Bag Manager (Bag Tab)

- **`BagManagerView.swift`** — Club list grouped by type (driver/wood/hybrid/iron/wedge/putter) with detail view for editing distances
- **`BagTemplatePicker.swift`** — 6-template selector with confirmation alert before replacing existing bag:
  - **Beginner** (9 clubs, Driver 200y)
  - **Standard** (14 clubs, Driver 240y)
  - **Low Handicap** (14 clubs, Driver 275y, 3 wedges)
  - **Senior** (13 clubs, Driver 210y, more hybrids)
  - **Women's** (12 clubs, Driver 180y)
  - **Junior** (8 clubs, Driver 160y)
- Add custom clubs with type + avg distance

### 6.7 Course Library

- **`CourseLibraryView.swift`** — Saved courses list with favorites, + menu with three options: Browse 500+ Courses, Community Courses, Create Custom Course
- **`BundledCourseBrowser.swift`** — Search/browse 661 pre-loaded courses from `courses.json` with state filter chips
- **`CommunityCourseBrowser.swift`** — CloudKit public database browse + import with upvote system
- **`CourseDetailView`** (in `CourseLibraryView.swift`) — Read-only course detail with map, favorite toggle

### 6.8 Settings

- **`SettingsView.swift`** — Profile, Subscription, Data, Appearance, Notifications, Support, Legal, About, Danger Zone
  - **Edit Profile** (name, handicap)
  - **Upgrade to Pro** / **Redeem Offer Code** (`.offerCodeRedemption`)
  - **Export CSV** (share sheet)
  - **Course Library** link
  - **Appearance**: System / Light / Dark (applied via `.preferredColorScheme`)
  - **Enable Notifications** (permission request)
  - **Rate TeeMetrics** (`requestReview`)
  - **Customer Support / Terms / Privacy** (GitHub Pages links)
  - **Version** + **Rounds Logged** counters
  - **Delete All Data** (destructive with confirmation)
- **`SubscriptionView.swift`** — Paywall with 4 feature sections, 3 pricing cards (Yearly highlighted with "BEST VALUE" badge), 3-day trial guarantee, Restore Purchases, Terms/Privacy links

### 6.9 Sharing & Export

- **`RoundCardRenderer.swift`** — Generates shareable images via `ImageRenderer`:
  - **Feed card** (4:5) with header, score circle, stats grid, mini scorecard
  - **Story card** (9:16) with giant score, stat pills
- **`RoundShareSheet`** (in same file) — Format picker + `ShareLink` with rendered image
- **`PDFReportGenerator.swift`** — `UIGraphicsPDFRenderer` for US Letter PDF with header, course info, summary stats, front/back 9 scorecard

### 6.10 Notifications

- **`NotificationManager.swift`** — Local notifications only (no APNs):
  - Permission request
  - 14-day inactivity reminder (scheduled on round finish)
  - Achievement unlock notifications
  - Weekly summary (Sundays 10am, repeating)
  - Handicap drop notification

### 6.11 Siri Shortcuts

- **`AppIntents.swift`** — 3 App Intents via `AppShortcutsProvider`:
  1. **StartRoundIntent** — "Hey Siri, start a round in TeeMetrics" (opens app)
  2. **CheckHandicapIntent** — Reads `cachedHandicap` from UserDefaults, returns spoken handicap
  3. **CheckLastRoundIntent** — Reads last round from App Group UserDefaults

### 6.12 Progressive Monetization

- **`GatingManager.swift`** — Feature gating:
  - First **5 rounds** → free access to everything
  - After 5 rounds → stats/analytics/comparison/recommendations are pro-gated
  - **`.proGated(.feature)`** view modifier replaces content with upgrade prompt
  - Round logging is **never** gated — free tier always allows logging

### 6.13 Achievements

- **`AchievementsManager.swift`** — 17 achievements evaluated on round finish:
  - Round milestones: First Round, 5, 10, 25, 50, 100 rounds
  - Score milestones: First Birdie, Eagle Eye, Sub-100, Sub-90, Sub-80, Sub-70
  - Stat milestones: 10 GIR, 50% Fairways, Under 30 Putts
  - Streaks: 3-Round Week, Improving Trend
- Newly-earned achievements trigger local notifications
- Earned list persisted in `UserDefaults.standard.stringArray(forKey: "earnedAchievements")`

### 6.14 Course Auto-Detection

- **`CourseDetection.swift`** — `CoreLocation` singleton:
  - Requests "When In Use" authorization
  - Finds courses within 50km of current location
  - Sorts by distance
  - Human-readable distance ("2.4 mi", "850 ft")
  - Used in `NewRoundView` to suggest nearby course chip

### 6.15 Stats Engine

- **`StatsCalculator.swift`** — Pure functions, no state:
  - **Handicap Index** (simplified USGA): best N of last 20 differentials × 0.96
  - **Strokes Gained**: Putting (1.8 baseline), Approach (GIR proxy), Off-Tee (fairway proxy), Short Game (scramble proxy)
  - Aggregate stats: avg score, avg putts, avg FW%, avg GIR%
  - Best score, score trend (last 5 vs prior 5)
  - **Handicap projection**: rate of change over 3 months, projected 3 months forward
  - **Week streak**: consecutive weeks with at least one round
  - Days since last round

### 6.16 Post-Round Celebration

- **`RoundCelebrationView.swift`** — Full-screen celebration after round finish:
  - Spring-animated trophy/flag icon
  - Animated score reveal
  - Stats reveal (front/back 9, putts, FW%, GIR%)
  - Auto-generated highlights ("1 eagle!", "5 birdies", "Under 30 putts")
  - **Confetti explosion** for personal bests (60 particles, physics-based)
  - "Share Round Card" button (opens `RoundShareSheet`)
  - "Done" to dismiss

### 6.17 Animation Utilities

- **`Animations.swift`** — Shared view modifiers:
  - `slideIn(delay:)` — spring animation with opacity + offset
  - `bounceTap()` — scale effect on press
  - `AnimatedNumber` — count-up animation
  - `AchievementUnlockOverlay` — auto-dismissing unlock banner
  - Shimmer loading effect

---

## 7. Features Partially Built / Stubbed

### 7.1 HealthKit Integration — STUBBED
- Info.plist contains `NSHealthShareUsageDescription` and `NSHealthUpdateUsageDescription`
- **No HealthKit code anywhere in the project**
- **TODO:** Either implement workout logging on round finish, or remove the plist keys (Apple rejected the first submission for this — Guideline 2.5.1)

### 7.2 AVFoundation Voice Notes — STUBBED
- Info.plist contains `NSMicrophoneUsageDescription`
- **No AVFoundation code exists**
- `HoleEntry.notes` is a text field only; original spec mentioned voice notes per shot
- **TODO:** Either implement voice recording in `ShotTrackerView` or remove the plist key

### 7.3 iOS-Side WatchConnectivity — NOT IMPLEMENTED
- The Watch app has a complete `WatchConnector` (`WCSessionDelegate`)
- **The iPhone app has no `WCSessionDelegate` and never calls `WCSession.default.sendMessage`**
- The Watch can send scores to the phone, but the phone can't push course data to the Watch
- **TODO:** Create `iOSWatchConnector` service, activate session in `TeeMetricsApp.onAppear`, push round start/hole/pars from `LiveRoundView`

### 7.4 CloudKit Community Courses — PARTIALLY WIRED
- `CloudKitCourseService` is fully implemented (upload, search, upvote, import)
- `CommunityCourseBrowser` view is built and accessible from `CourseLibraryView` + `NewRoundView`
- CloudKit capability must be manually enabled in Xcode Signing & Capabilities
- **Requires one-time setup in CloudKit Dashboard**: create `SharedCourse` record type with fields + Queryable indexes on `recordName`, `name`, `state`, and Sortable index on `upvotes`
- **TODO:** Verify CloudKit schema is deployed, test upload/fetch flow

### 7.5 Offline MapKit Region Caching — NOT IMPLEMENTED
- Original spec mentioned "offline MapKit tile caching for 5 courses free / unlimited Pro"
- MapKit is used for display only — no tile caching
- **TODO:** Implement `MKMapSnapshotter` or tile prefetching if this feature is desired

### 7.6 CSV Import — NOT IMPLEMENTED
- CSV export exists (`SettingsView.exportCSV()`)
- No import path
- **TODO:** Implement if users request migration from other apps

### 7.7 Sample Data UI — DEV ONLY, HIDDEN
- `SampleDataSeeder.swift` creates 2 courses + 5 sample rounds
- The "Load Sample Data" button was **removed from Settings** before submission
- The seeder is still in the codebase and can be called programmatically
- **TODO:** Either remove entirely or add a debug-only menu flag

### 7.8 Practice Sessions — MODEL BUILT, UI MINIMAL
- `PracticeSession` and `PracticeShot` models exist in SwiftData schema
- `PracticeView.swift` allows creating sessions
- **No aggregated practice stats view** (e.g., average drives at the range)
- **TODO:** Add practice stats to StatsView or create dedicated view

### 7.9 Goals Progress Auto-Update — NOT HOOKED UP
- `Goal.currentValue` exists but is **never updated after creation**
- Progress bars show 0% until manually edited
- **TODO:** After each round finish, update `currentValue` based on `goalType` (e.g., for "score" type, set to latest round's totalScore)

### 7.10 Widget Active Round Updates — PARTIAL
- `WidgetDataWriter.updateActiveRound` is called from `LiveRoundView.onChange(of: currentHole)`
- **But not on hole finish or score changes**
- Widget may show stale scores during a round until you move to the next hole
- **TODO:** Call `updateActiveRound` on every score change

### 7.11 Scheduled Handicap Drop Notification — UNUSED
- `NotificationManager.scheduleHandicapDrop(newHandicap:)` exists
- **Never called anywhere** — should fire when handicap recalculates lower
- **TODO:** Hook into round finish in `LiveRoundView`

---

## 8. Data Model

### 8.1 SwiftData Schema

Defined in `TeeMetricsApp.swift`:

```swift
var sharedModelContainer: ModelContainer = {
    let schema = Schema([
        Golfer.self,
        GolfCourse.self,
        HoleInfo.self,
        GolfRound.self,
        HoleEntry.self,
        ShotEntry.self,
        Club.self,
        Bag.self,
        Goal.self,
        PracticeSession.self,
        PracticeShot.self,
    ])
    let config = ModelConfiguration(
        schema: schema,
        isStoredInMemoryOnly: false,
        cloudKitDatabase: .none  // ← SwiftData sync disabled
    )
    return try ModelContainer(for: schema, configurations: [config])
}()
```

**11 `@Model` classes total.**

### 8.2 Model Definitions

#### Golfer
- `id: UUID`, `name: String`, `handicapIndex: Double`
- `homeCourseID: UUID?`, `defaultBagID: UUID?`
- `createdAt: Date`, `avatarSystemName: String` (defaults to "figure.golf")
- **No relationships** — references other models by ID (loosely coupled)

#### GolfCourse
- `id: UUID`, `name`, `city`, `state`, `latitude: Double`, `longitude: Double`
- `totalPar: Int` (default 72), `totalYardage: Int` (default 6500)
- `slopeRating: Double` (default 113), `courseRating: Double` (default 72.0)
- `createdAt: Date`, `isFavorite: Bool`
- **Relationships:**
  - `holes: [HoleInfo]` with `.cascade` delete, inverse `\HoleInfo.course`
  - `rounds: [GolfRound]` with `.cascade` delete, inverse `\GolfRound.course`

#### HoleInfo
- `id: UUID`, `holeNumber: Int`, `par: Int`, `yardage: Int`, `handicapRating: Int`
- `course: GolfCourse?` (inverse side, no `@Relationship` annotation)

#### GolfRound
- `id: UUID`, `date: Date`, `course: GolfCourse?`
- `weatherNotes: String`, `totalScore: Int`, `totalPutts: Int`
- `playersCount: Int`, `playerNames: String` (comma-separated)
- `isCompleted: Bool`, `notes: String`, `currentHole: Int`
- `createdAt: Date`
- **Relationships:** `holeEntries: [HoleEntry]` cascade, inverse `\HoleEntry.round`
- **Computed:** `scoreToPar`, `scoreToParString`, `fairwayPercentage`, `girPercentage`, `averagePutts`, `frontNine`, `backNine`
- **Method:** `recalculateTotals()` — sums hole entries into `totalScore` and `totalPutts`

#### HoleEntry
- `id: UUID`, `holeNumber: Int`, `par: Int`, `score: Int`, `putts: Int`, `penalties: Int`
- `fairwayHit: Bool?`, `greenInRegulation: Bool`
- `sandSave: Bool?`, `upAndDown: Bool?`
- `notes: String`
- **Relationships:**
  - `round: GolfRound?` (inverse side)
  - `holeInfo: HoleInfo?` (⚠️ no inverse, see Known Bugs)
  - `shots: [ShotEntry]` cascade, inverse `\ShotEntry.holeEntry`

#### ShotEntry
- `id: UUID`, `shotNumber: Int`, `clubUsed: String`, `distanceYards: Int`
- `lieType: String` (tee/fairway/rough/bunker/fringe/green/penalty — see `LieType` enum)
- `result: String` (perfect/hit/push/pull/slice/hook/topped/chunked — see `ShotResult` enum)
- `notes: String`
- `holeEntry: HoleEntry?` (inverse side)

#### Club
- `id: UUID`, `name: String`, `clubType: String` (driver/wood/hybrid/iron/wedge/putter — see `ClubType` enum)
- `avgDistance: Int`, `maxDistance: Int`, `minDistance: Int`, `totalShots: Int`
- `lastUsed: Date?`, `sortOrder: Int`
- `bag: Bag?` (inverse side)
- **Method:** `updateDistance(newDistance:)` — maintains running avg, updates min/max

#### Bag
- `id: UUID`, `name: String`, `isDefault: Bool`, `createdAt: Date`
- `clubs: [Club]` cascade, inverse `\Club.bag`
- `sortedClubs` computed property
- **Factory:** `Bag.createDefault()` → uses `.standard` template
- **Factory:** `Bag.createFromTemplate(_ template: BagTemplate)` → creates from 6 templates

#### Goal
- `id: UUID`, `title: String`, `goalType: String`
- `targetValue: Double`, `currentValue: Double`
- `deadline: Date`, `isCompleted: Bool`, `createdAt: Date`
- Computed: `progress`, `progressPercentage`, `isExpired`, `daysRemaining`, `goalTypeIcon`
- ⚠️ `currentValue` is never auto-updated (see Section 7.9)

#### PracticeSession
- `id: UUID`, `date: Date`
- `sessionType: String` (range/putting/chipping/full)
- `durationMinutes: Int`, `notes: String`, `clubsUsed: String` (comma-separated)
- `shots: [PracticeShot]` cascade, inverse `\PracticeShot.session`

#### PracticeShot
- `id: UUID`, `clubUsed: String`, `distanceYards: Int`, `result: String`
- `session: PracticeSession?` (inverse side)

### 8.3 UserDefaults Keys

**Standard UserDefaults** (`UserDefaults.standard`):

| Key | Type | Where Written | Purpose |
|-----|------|--------------|---------|
| `hasCompletedOnboarding` | Bool | `OnboardingView` via `@AppStorage` | Gate to MainTabView |
| `selectedAppearance` | String | `SettingsView` via `@AppStorage` | "system"/"light"/"dark" |
| `earnedAchievements` | [String] | `LiveRoundView.finishRound()` | Array of earned achievement raw values |
| `cachedHandicap` | Double | `LiveRoundView.finishRound()` | For Siri `CheckHandicapIntent` |

**App Group UserDefaults** (`group.com.teemetrics.shared`):

See Section 5 (Widget Extension) for full list of `widget_*` keys.

### 8.4 Persistence Layer Summary

- **Primary store:** SwiftData local SQLite (no CloudKit sync)
- **Widget data:** App Group UserDefaults
- **Community courses:** CloudKit public database (`iCloud.com.teemetrics.app`, record type `SharedCourse`)
- **Bundled courses:** `TeeMetrics/Resources/courses.json` (661 courses, 51 states)
- **App settings:** UserDefaults.standard via `@AppStorage`

---

## 9. Authentication

**There is no authentication.** TeeMetrics is designed as a fully local, privacy-first app. There are no user accounts, no sign-in screens, and no identity providers.

- **No Sign in with Apple**
- **No Firebase Auth**
- **No custom backend auth**
- **No OAuth / no social login**

The "user" is identified solely by the first `Golfer` entity created during onboarding. Deleting the app removes all data. iCloud sync is **not** enabled on the main data container (SwiftData `.cloudKitDatabase: .none`).

The only identity-adjacent integration is:
- **iCloud account availability check** (`CKContainer.accountStatus()`) used by `CloudKitCourseService` to determine whether community course features are available. Users who sign in to iCloud on their device get access automatically — no in-app authentication UI required.

---

## 10. Third-Party Integrations & Backend Services

### Backend Services

**NONE** in the traditional sense. There is no:

- Custom backend server
- REST API
- GraphQL endpoint
- WebSocket connection
- Cloud Functions
- Database server

### Apple-Hosted Services Used

| Service | Purpose | Where |
|---------|---------|-------|
| **CloudKit Public Database** | Community course sharing | `CloudKitCourseService.swift` |
| **App Store Connect / StoreKit** | IAP / subscriptions | `SubscriptionManager.swift` |
| **MapKit (Apple servers)** | Map tile delivery | `AddCourseView`, `CourseLibraryView` |
| **Siri / App Intents** | Voice shortcuts | `AppIntents.swift` |

### CloudKit Container

- **Container ID:** `iCloud.com.teemetrics.app`
- **Database:** Public only (`container.publicCloudDatabase`)
- **Record Type:** `SharedCourse`
- **Schema fields:** `name`, `city`, `state`, `latitude`, `longitude`, `totalPar`, `totalYardage`, `slopeRating`, `courseRating`, `holesJSON` (stringified array), `contributorName`, `upvotes`
- **Required indexes:** `recordName` (Queryable), `name` (Queryable), `state` (Queryable), `upvotes` (Sortable)

### API Keys / Secrets

**None.** There are no API keys anywhere in the codebase. No `.env` files, no Keychain secrets, no hardcoded tokens. Everything uses Apple-native auth (device's iCloud account for CloudKit, Apple ID for StoreKit).

### External HTTP Requests

The app makes **no direct HTTP/HTTPS requests** to any external service. All network activity is routed through:
- Apple's StoreKit (StoreKit 2 auto-handles receipt verification)
- Apple's CloudKit (via `CKContainer`)
- Apple's MapKit tile servers (via `Map` view)

No `URLSession`, no `URLRequest`, no AF-style networking libraries.

### Anthropic / AI APIs

**Not used.** There are no LLM, AI, or ML integrations. All "insights" are rule-based in `StatsCalculator.swift`:

```swift
if avgPutts > 2.0 {
    insightCard(text: "Putting is your biggest opportunity. ...")
}
```

---

## 11. Navigation Structure

### Root Gate

`TeeMetricsApp.swift` uses `@AppStorage("hasCompletedOnboarding")` to switch between `OnboardingView` and `MainTabView`.

```swift
Group {
    if hasCompletedOnboarding {
        MainTabView()
    } else {
        OnboardingView()
    }
}
.preferredColorScheme(colorScheme)
```

### Onboarding Flow

```
OnboardingView
  ├─ Half-sheet: OnboardingBagSheet (bag template picker)
  └─ Tap "Get Started"
       └─ Full-screen cover: WelcomeWalkthroughView
            ├─ Page 1: Start a Round
            ├─ Page 2: Track Your Stats
            └─ Page 3: Set Goals
                 └─ "Let's Go!" → sets hasCompletedOnboarding = true
                                  → MainTabView
```

### MainTabView — 5 Tabs

```
TabView
├─ Tab 0: DashboardView (Home)
│   ├─ NavigationLink → LiveRoundView (active round resume)
│   ├─ Sheet: NewRoundView
│   ├─ NavigationLink → RoundDetailView (recent rounds)
│   ├─ NavigationLink → GoalsView
│   ├─ NavigationLink → AchievementsView
│   ├─ NavigationLink → PracticeView
│   └─ NavigationLink → SubscriptionView (pro banner)
│
├─ Tab 1: RoundHistoryView (Rounds)
│   └─ NavigationLink → RoundDetailView
│        ├─ Sheet: RoundShareSheet (share card)
│        └─ Sheet: PDF share sheet
│
├─ Tab 2: StatsView
│   ├─ NavigationLink → RoundComparisonView
│   ├─ NavigationLink → AchievementsView
│   ├─ NavigationLink → GoalsView
│   │    └─ Sheet: AddGoalView
│   └─ Pro-gated → Sheet: SubscriptionView (via .proGated modifier)
│
├─ Tab 3: BagManagerView
│   ├─ NavigationLink → ClubDetailView (edit club)
│   ├─ Sheet: AddClubView
│   └─ Sheet: BagTemplatePicker (reset to template)
│
└─ Tab 4: SettingsView
    ├─ NavigationLink → EditProfileView
    ├─ NavigationLink → SubscriptionView
    ├─ .offerCodeRedemption (Apple sheet)
    ├─ NavigationLink → CourseLibraryView
    │    ├─ NavigationLink → CourseDetailView
    │    ├─ Sheet: AddCourseView
    │    │    └─ Alert: "Share with Community?"
    │    ├─ Sheet: BundledCourseBrowser (661 courses)
    │    └─ Sheet: CommunityCourseBrowser (CloudKit)
    └─ Share sheet: CSV export
```

### NewRound → LiveRound Flow

```
NewRoundView (sheet)
  ├─ Course picker (shows "Nearby" from CoreLocation)
  ├─ "Browse 500+ Courses" → Sheet: BundledCourseBrowser
  ├─ "Community Courses" → Sheet: CommunityCourseBrowser
  ├─ "Add New Course" → Sheet: AddCourseView
  └─ "Start Round" button
       └─ navigationDestination → LiveRoundView
            ├─ Running score header
            ├─ TabView (horizontal pager, 18 holes)
            │    └─ HoleLoggerView per page
            │         └─ Sheet: ShotTrackerView
            ├─ Hole dot navigator
            └─ "Finish" button
                 ├─ Alert: "Finish Round?"
                 └─ Full-screen cover: RoundCelebrationView
                      └─ "Share Round Card" → Sheet: RoundShareSheet
```

### Navigation Patterns

- **NavigationStack** is used at the root of each tab (so each tab has its own back stack)
- **Sheets** are used for modal forms (NewRound, AddCourse, etc.)
- **Full-screen covers** are used for immersive experiences (celebration, walkthrough)
- **`.navigationDestination(isPresented:)`** is used in NewRoundView for programmatic push after round creation
- **`.offerCodeRedemption(isPresented:)`** is an iOS 16+ API used in SettingsView for Apple's native offer code sheet

---

## 12. Monetization

### StoreKit 2 Products

Defined in `SubscriptionManager.swift`:

```swift
static let monthlyID = "com.teemetrics.pro.monthly"
static let yearlyID = "com.teemetrics.pro.yearly"
static let lifetimeID = "com.teemetrics.pro.lifetime"
```

### Subscription Tiers

| Tier | Product ID | Price | Type | Trial |
|------|-----------|-------|------|-------|
| **Monthly** | `com.teemetrics.pro.monthly` | $4.99/mo | Auto-Renewable Subscription | None |
| **Yearly** | `com.teemetrics.pro.yearly` | $29.99/yr | Auto-Renewable Subscription | **3-day free trial** |
| **Lifetime** | `com.teemetrics.pro.lifetime` | $49.99 | Non-Consumable | N/A |

All three are in the same **subscription group** (for the AR subs) named **"TeeMetrics Pro"** in App Store Connect.

### SubscriptionManager Singleton

`@MainActor @Observable final class SubscriptionManager`

Key properties:
- `isProUser: Bool` — true if any entitlement is active
- `products: [Product]` — loaded from App Store via `Product.products(for:)`
- `purchasedProductIDs: Set<String>` — current entitlements

Key methods:
- `loadProducts()` — called on SubscriptionView `.task`
- `purchase(_ product:)` — triggers StoreKit purchase flow
- `restore()` — calls `AppStore.sync()` + updates purchased state
- `updatePurchasedProducts()` — iterates `Transaction.currentEntitlements`
- Transaction listener started in `init()` via `Task.detached`

### Progressive Gating (GatingManager)

`GatingManager.freeRoundLimit = 5` — users get 5 completed rounds with **full feature access** before gating kicks in.

**After 5 rounds**, these features become Pro-only:
- Advanced stats
- Strokes gained charts
- Handicap projection
- Round comparison
- Club recommendations
- CSV export

**Always free:**
- Round logging (unlimited)
- Basic scorecard/stats
- 660+ pre-loaded courses
- Bag templates
- Watch app
- Celebration screen

**Always Pro:**
- PDF export
- iCloud sync (not implemented but listed)

### Paywall Placement

1. **Dashboard banner** — "Unlock Pro" gradient card (always visible for non-Pro)
2. **Free rounds remaining card** — shows countdown of remaining free rounds
3. **Settings → Subscription** — NavigationLink to SubscriptionView
4. **`.proGated(.feature)` modifier** — replaces gated content with upgrade prompt that triggers SubscriptionView sheet
5. **Post-round celebration** — not currently shown (opportunity)
6. **Stats tab** — `strokesGainedChart.proGated(.strokesGained)` and `handicapChart.proGated(.advancedStats)`

### Offer Codes

`SettingsView.swift` has a **"Redeem Offer Code"** button that uses Apple's native `.offerCodeRedemption(isPresented:)` API. This opens Apple's standard sheet for entering promo codes.

**Pre-configured offer code**: `JOHNNYWOODS` — intended to grant 1 free year of yearly subscription. Must be created in App Store Connect → Subscriptions → Pro Yearly → Offer Codes → Create Custom Code. **This is an App Store Connect task, not a code task.**

### StoreKit Configuration File

**None.** There is no local `.storekit` file in the Xcode project. The app loads products from the real App Store sandbox during review. This is intentional — `.storekit` files override sandbox and would cause review issues.

### Current App Store Review Status

- **Submitted**: April 9, 2026
- **Rejection reasons:**
  1. **Guideline 2.1(b)**: "Unable to purchase the subscriptions successfully" — likely because IAPs hadn't propagated to sandbox at review time, or the Paid Apps Agreement wasn't active. Developer has confirmed agreement is active and IDs match.
  2. **Guideline 2.5.1**: HealthKit APIs referenced in Info.plist without corresponding UI. **Fix: remove HealthKit usage description strings from Info.plist.**
- **Resubmission pending** after removing HealthKit strings.

---

## 13. Known Bugs, Tech Debt, & Refactor Candidates

### Critical / Must Fix Before Resubmission

| # | Issue | File | Impact |
|---|-------|------|--------|
| 1 | **HealthKit strings in Info.plist with no implementation** | `TeeMetrics/Info.plist` | **App Store rejection (2.5.1)** — must delete `NSHealthShareUsageDescription` and `NSHealthUpdateUsageDescription` |
| 2 | **Microphone string in Info.plist with no implementation** | `TeeMetrics/Info.plist` | Not yet flagged but same risk — delete `NSMicrophoneUsageDescription` until voice notes are implemented |

### Data Integrity / Correctness

| # | Issue | File | Impact |
|---|-------|------|--------|
| 3 | `HoleEntry.holeInfo` has no inverse relationship declared on either side | `HoleEntry.swift` / `GolfCourse.swift` | CloudKit compatibility warning (not currently a problem since SwiftData CloudKit sync is disabled) |
| 4 | `Goal.currentValue` never auto-updated after creation | `Goal.swift`, `LiveRoundView.finishRound()` | Goal progress bars always show 0% |
| 5 | Widget `updateActiveRound` only fires on hole change, not score change | `LiveRoundView.swift` | Stale score on widget during an active round |
| 6 | `NotificationManager.scheduleHandicapDrop` is never called | `LiveRoundView.swift` | Dead code — handicap drop notifications never fire |

### UX / Polish

| # | Issue | File | Impact |
|---|-------|------|--------|
| 7 | No keyboard "Done" toolbar on decimal pad inputs (handicap field) | `OnboardingView.swift`, `EditProfileView` | Users have to tap elsewhere to dismiss keyboard. `.onTapGesture` with `resignFirstResponder` exists but isn't applied everywhere |
| 8 | `ShotTrackerView` club buttons hardcode `selectedLie = .fairway` after adding a shot, which can be wrong on tee shots | `ShotTrackerView.swift` line ~180 | Minor UX annoyance |
| 9 | Celebration screen's confetti duration (3.0s) doesn't sync with stat reveals (2.3s total) | `RoundCelebrationView.swift` | Visual timing awkward |
| 10 | `StatCard` and `RoundRowView` in Dashboard use hardcoded `.black.opacity(0.04)` shadows that disappear in dark mode | `DashboardView.swift` | Cards feel flat in dark mode (CardStyle modifier is now adaptive but individual views bypass it) |
| 11 | `CourseDetailView` is read-only — no way to edit hole par/yardage for imported courses | `CourseLibraryView.swift` | Users can't correct bundled course data inline |
| 12 | PDF export button silently fails if generation returns empty Data | `RoundDetailView.swift` | No error messaging |

### Code Duplication

| # | Issue | File |
|---|-------|------|
| 13 | Widget keys are duplicated: `WidgetDataKeys` in main app + `Keys` (private) in widget target | `WidgetDataWriter.swift` + `TeeMetricsWidgets.swift` — intentional to avoid cross-target deps but means any new key must be added in both places |
| 14 | `LieType` and `ShotResult` enums live in `ShotEntry.swift` alongside the `@Model` — could be split |
| 15 | `BagTemplate` enum is a giant switch of club arrays in `Club.swift` (~100 lines) — could be a JSON or plist |

### Accessibility

| # | Issue | File |
|---|-------|------|
| 16 | No VoiceOver labels on score buttons in `HoleLoggerView.swift` beyond basic SwiftUI defaults |
| 17 | No Dynamic Type testing documented |
| 18 | Theme score colors were tuned for light mode; dark mode contrast not verified against WCAG |

### Architecture Issues

| # | Issue | File |
|---|-------|------|
| 19 | `ProGateModifier` calls `GatingManager.shared.requiresPro` outside of `@Observable` reactivity — won't re-render when `isProUser` changes unless the parent view re-renders | `GatingManager.swift` |
| 20 | `SubscriptionManager.init()` fires `Task { await updatePurchasedProducts() }` but doesn't await — race condition on first launch where `isProUser` may be stale for a moment |
| 21 | `CloudKitCourseService` has `import CoreLocation` and `import SwiftData` declared at the bottom of the file (line 243+). Unusual placement — should be at top |

### Missing

| # | Missing | Impact |
|---|---------|--------|
| 22 | **No unit tests** | Cannot verify handicap/strokes gained calculations remain correct |
| 23 | **No UI tests** | Cannot automate regression testing of flows |
| 24 | **No iOS-side WatchConnector** | Watch ↔ Phone sync is unidirectional (see Section 7.3) |
| 25 | **No error UI** — services like `CloudKitCourseService.errorMessage` are set but rarely surfaced |

---

## 14. What's NOT Built Yet (But Intended by Code/Comments)

Based on comments, Info.plist entries, original spec, and service stubs:

### 14.1 Implied by Info.plist

1. **HealthKit Workout Writing** — Info.plist says "save your golf round as a workout". No code exists. Intended: on `finishRound()`, create an `HKWorkout` of type `.golf` and write to HealthKit.
2. **HealthKit Activity Reading** — Info.plist says "track calories burned during rounds". No code exists. Intended: read step count / energy burned during round window and display on round detail.
3. **Voice Notes per Shot** — `NSMicrophoneUsageDescription` says "voice notes during rounds". `HoleEntry.notes` is text only. Intended: audio recording in `ShotTrackerView` or `HoleLoggerView`.

### 14.2 Implied by Code Stubs

4. **iOS-side WatchConnector** — Watch app has a complete `WatchConnector`. iOS app never sends data. Intended: push course pars, course name, and active state from iPhone to Watch when a round starts.
5. **Handicap drop notification trigger** — `NotificationManager.scheduleHandicapDrop` exists but is never called. Intended: fire after round finish if new handicap is lower than cached handicap.
6. **Goal auto-progress** — `Goal.currentValue` exists but is never written to after `Goal.init`. Intended: after each round finish, update matching goals based on `goalType`.
7. **Practice session stats** — `PracticeSession` model is in the schema and `PracticeView` logs sessions, but there's no analytics view for practice data. Intended: club-by-club avg distance trend from practice.

### 14.3 Implied by Original Spec

8. **Offline MapKit tile caching** — Original spec: "offline MapKit tile caching for 5 courses". Not implemented. Intended: use `MKMapSnapshotter` or tile prefetching.
9. **Home Screen widget variant: "Today's Round"** — Spec mentions two widgets. Only one widget (`TeeMetricsLastRoundWidget`) is registered. Intended: a second widget showing current streak / goal progress / upcoming tee time.
10. **Lock Screen complication on Watch** — Not implemented. Intended: circular/inline complication showing current score or hole.
11. **"Hot Streaks" insight cards** — Original spec mentioned rule-based insight cards. `StatsView.insightsSection` has some but the Dashboard has a simpler streak banner. Could be expanded.

### 14.4 Pro Features Listed but Not Built

Listed on SubscriptionView paywall but not actually implemented:

12. **iCloud Sync** — Listed as a Pro feature ("Payment history"). SwiftData CloudKit sync is **explicitly disabled** (`cloudKitDatabase: .none`). Intended: flip to `.private` when user becomes Pro. This would require CloudKit schema for **all** SwiftData models, which is non-trivial.
13. **Ad-free experience** — Listed but there are **no ads** in the app at all. This line should be removed from the paywall or ads should be added to the free tier.

### 14.5 Nice-to-Haves Mentioned in Git History

14. **TestFlight beta** — Never configured
15. **App Store screenshots** — Taken manually but not using `SnapshotTesting`
16. **Localization** — App is English-only; no `.strings` files, no `.xcstrings` catalog
17. **iPad-optimized layouts** — Currently iPhone-first, iPad inherits iPhone layout via UIKit's compatibility layer

---

## 15. File Count & Complexity Summary

| Category | Files | Approx LoC |
|----------|-------|-----------|
| App entry + navigation | 2 | ~100 |
| Models | 8 | ~500 |
| Services | 13 | ~1,400 |
| Views | 23 | ~4,500 |
| Extensions | 4 | ~300 |
| Widget extension | 1 | ~250 |
| Watch app | 2 | ~220 |
| Resources (courses.json) | 1 | 661 courses |
| Legal docs (HTML) | 4 | ~800 |
| **Total Swift LoC** | **53 files** | **~7,800** |

---

## 16. How to Run Locally

1. Clone the repo: `git clone -b claude/ios-swiftui-development-v7pEm <repo-url>`
2. Open `TeeMetrics/TeeMetrics.xcodeproj` in **Xcode 15.0+**
3. Select the **TeeMetrics** scheme and an iOS 17+ simulator (or real device)
4. **Signing**: Set your Apple Developer team on all three targets (main app, widget, watch)
5. **Capabilities**: Ensure App Groups (`group.com.teemetrics.shared`) and CloudKit (`iCloud.com.teemetrics.app`) are enabled on the main target and widget target
6. **Cmd+R** to build and run

### First-Launch Flow for Testing
1. Fill in name + optional handicap, pick a bag template, tap "Get Started"
2. Complete the 3-page walkthrough
3. On the Home tab, tap "Start New Round"
4. Select any course (or tap "Browse 500+ Courses" for preloaded ones)
5. Score holes with the quick-score buttons
6. Tap "Finish" on the last hole → celebration screen → "Done"
7. Check Rounds tab, Stats tab, Bag tab, Settings tab

### Developer Notes
- There is no `SampleDataSeeder` UI button anymore — to seed test data, call `SampleDataSeeder.loadSampleData(into: modelContext)` manually in a debug view
- No `.storekit` file means you need a sandbox Apple ID to test IAPs
- CloudKit community features require a signed-in iCloud account on the device/simulator

---

## 17. Glossary / Domain Terms

- **GIR** — Green In Regulation (ball reaches the green in ≤ par-2 strokes)
- **FW%** — Fairway hit percentage (par 4+ holes only)
- **Strokes Gained** — Performance metric comparing player to baseline at each shot category
- **Handicap Index** — USGA-standardized measure of a golfer's potential (lower = better)
- **Slope Rating** — Course difficulty for a bogey golfer (113 = neutral)
- **Course Rating** — Expected score for a scratch golfer
- **Up-and-Down** — Scoring par or better after missing the green
- **Sand Save** — Scoring par or better when in a greenside bunker
- **Scramble** — Making par after missing the green in regulation
- **Eagle** — 2 under par on a hole
- **Birdie** — 1 under par
- **Bogey** — 1 over par
- **To-Par** — Cumulative difference from par across all holes played

---

**End of Project Brief**

This document was generated by reading all source files in the repository. It reflects the state of the project as of the latest commit on branch `claude/ios-swiftui-development-v7pEm`. For any section that feels incomplete or outdated, re-read the relevant files and update this brief accordingly.
