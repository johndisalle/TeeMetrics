// MARK: - Watch Round View
// Tee-aware per-hole scoring on the Apple Watch.
//
// Rounds are started from the iPhone only — this view shows an idle
// "Start your round on iPhone first." screen until the Phone pushes a
// round-start payload via WatchConnectivity. The Watch never creates a
// round on its own.
//
// Synced payload from `WatchSyncManager` (Phone side):
//   isActive:    Bool       — true when a round is in progress
//   courseName:  String     — display name
//   teeName:     String?    — e.g. "White" (omitted when no tee selected)
//   holePars:    [Int]      — 18-element par array for the active tee
//   startedAt:   TimeInterval — bumped on every fresh round start
//
// Persistence: the active payload is mirrored into UserDefaults so a
// force-quit + relaunch mid-round restores tee + pars without needing the
// Phone to be reachable.

import SwiftUI
import Combine
import WatchConnectivity

struct WatchRoundView: View {
    @StateObject private var connector = WatchConnector()
    @State private var currentHole = 1
    @State private var scores: [Int] = Array(repeating: 0, count: 18)
    @State private var putts: [Int] = Array(repeating: 0, count: 18)
    @State private var pars: [Int] = Array(repeating: 4, count: 18)
    @State private var courseName: String = "TeeMetrics"
    @State private var teeName: String? = nil
    @State private var isRoundActive = false

    // UserDefaults keys for mid-round persistence.
    private let kPars = "watch.holePars"
    private let kCourse = "watch.courseName"
    private let kTee = "watch.teeName"
    private let kActive = "watch.isActive"
    private let kStartedAt = "watch.startedAt"
    private let kScores = "watch.scores"
    private let kPutts = "watch.putts"
    private let kCurrentHole = "watch.currentHole"

    private var currentIndex: Int { currentHole - 1 }
    private var runningScore: Int { scores.prefix(currentHole).reduce(0, +) }
    private var runningPar: Int { pars.prefix(currentHole).reduce(0, +) }
    private var toPar: Int { runningScore - runningPar }
    private var completedHoles: Int { scores.filter { $0 > 0 }.count }

    var body: some View {
        NavigationStack {
            if isRoundActive {
                TabView(selection: $currentHole) {
                    ForEach(1...18, id: \.self) { hole in
                        watchHoleView(hole: hole)
                            .tag(hole)
                    }
                }
                .tabViewStyle(.verticalPage)
                .navigationTitle(headerTitle)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("End") {
                            endRound()
                        }
                        .foregroundStyle(.red)
                    }
                }
            } else {
                // Idle screen — Watch cannot start its own round.
                VStack(spacing: 12) {
                    Image(systemName: "iphone.and.arrow.forward")
                        .font(.title)
                        .foregroundStyle(.green)
                    Text("Start your round on iPhone first.")
                        .font(.caption)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.primary)
                    Text("This Watch will follow along automatically once you tee off.")
                        .font(.caption2)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                }
                .padding()
            }
        }
        .onAppear {
            connector.onDataReceived = { data in
                handlePhoneData(data)
            }
            restoreFromDefaults()
        }
    }

    /// Compact title that shows hole number plus tee name when available.
    private var headerTitle: String {
        if let teeName, !teeName.isEmpty {
            return "H\(currentHole) · \(teeName)"
        }
        return "H\(currentHole)"
    }

    private func watchHoleView(hole: Int) -> some View {
        let idx = hole - 1
        return VStack(spacing: 4) {
            // Header — course + tee subtitle + par chip
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(courseName)
                        .font(.caption2.bold())
                        .lineLimit(1)
                    if let teeName, !teeName.isEmpty {
                        Text("\(teeName) tees")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                Spacer()
                Text("P\(pars[idx])")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Score stepper
            HStack {
                Button {
                    if scores[idx] > 0 { scores[idx] -= 1 }
                    WKInterfaceDevice.current().play(.click)
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.title3)
                }
                .buttonStyle(.plain)

                Text("\(scores[idx])")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .frame(width: 50)
                    .foregroundStyle(scoreColor(score: scores[idx], par: pars[idx]))

                Button {
                    scores[idx] += 1
                    WKInterfaceDevice.current().play(.click)
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                }
                .buttonStyle(.plain)
            }

            // Putts
            HStack {
                Text("Putts")
                    .font(.caption2)
                Spacer()
                Button { if putts[idx] > 0 { putts[idx] -= 1 } } label: {
                    Image(systemName: "minus.circle").font(.caption)
                }
                .buttonStyle(.plain)
                Text("\(putts[idx])")
                    .font(.caption.bold())
                    .frame(width: 20)
                Button { putts[idx] += 1 } label: {
                    Image(systemName: "plus.circle").font(.caption)
                }
                .buttonStyle(.plain)
            }

            // Running total
            Divider()
            HStack {
                Text("Thru \(completedHoles)")
                    .font(.caption2)
                Spacer()
                Text("\(runningScore)")
                    .font(.caption.bold())
                Text(toPar == 0 ? "E" : (toPar > 0 ? "+\(toPar)" : "\(toPar)"))
                    .font(.caption2.bold())
                    .foregroundStyle(toPar <= 0 ? .green : .red)
            }
        }
        .padding(.horizontal, 4)
        .onChange(of: scores[idx]) { _, _ in persistAndSync() }
        .onChange(of: putts[idx]) { _, _ in persistAndSync() }
        .onChange(of: currentHole) { _, _ in persistAndSync() }
    }

    private func scoreColor(score: Int, par: Int) -> Color {
        guard score > 0 else { return .primary }
        let diff = score - par
        if diff <= -1 { return .red }
        if diff == 0 { return .green }
        return .primary
    }

    // MARK: - Phone Sync

    private func persistAndSync() {
        let d = UserDefaults.standard
        d.set(scores, forKey: kScores)
        d.set(putts, forKey: kPutts)
        d.set(currentHole, forKey: kCurrentHole)
        connector.send([
            "scores": scores,
            "putts": putts,
            "currentHole": currentHole,
        ])
    }

    private func handlePhoneData(_ data: [String: Any]) {
        let d = UserDefaults.standard

        if let p = data["holePars"] as? [Int], p.count == 18 {
            pars = p
            d.set(p, forKey: kPars)
        }
        if let name = data["courseName"] as? String {
            courseName = name
            d.set(name, forKey: kCourse)
        }
        // teeName may be absent (course has no tees) — only overwrite when
        // the key is actually present in the payload.
        if data.keys.contains("teeName") {
            let name = data["teeName"] as? String
            teeName = name
            if let name { d.set(name, forKey: kTee) } else { d.removeObject(forKey: kTee) }
        }
        if let started = data["startedAt"] as? TimeInterval {
            let lastStarted = d.double(forKey: kStartedAt)
            if started > lastStarted {
                // Fresh round — reset local scoring buffers.
                scores = Array(repeating: 0, count: 18)
                putts = Array(repeating: 0, count: 18)
                currentHole = 1
                d.set(scores, forKey: kScores)
                d.set(putts, forKey: kPutts)
                d.set(currentHole, forKey: kCurrentHole)
                d.set(started, forKey: kStartedAt)
            }
        }
        if let active = data["isActive"] as? Bool {
            isRoundActive = active
            d.set(active, forKey: kActive)
            if !active {
                // Round ended on Phone — clear persisted state so a relaunch
                // returns to the idle screen.
                clearDefaults()
            }
        }
    }

    /// Restores any in-progress round state from UserDefaults so a
    /// force-quit + relaunch lands the user back on their current hole
    /// with the correct pars and tee name.
    private func restoreFromDefaults() {
        let d = UserDefaults.standard
        if let p = d.array(forKey: kPars) as? [Int], p.count == 18 {
            pars = p
        }
        if let name = d.string(forKey: kCourse) {
            courseName = name
        }
        if let name = d.string(forKey: kTee) {
            teeName = name
        }
        if let s = d.array(forKey: kScores) as? [Int], s.count == 18 {
            scores = s
        }
        if let p = d.array(forKey: kPutts) as? [Int], p.count == 18 {
            putts = p
        }
        let hole = d.integer(forKey: kCurrentHole)
        if hole >= 1 && hole <= 18 {
            currentHole = hole
        }
        isRoundActive = d.bool(forKey: kActive)
    }

    private func clearDefaults() {
        let d = UserDefaults.standard
        for key in [kPars, kCourse, kTee, kActive, kStartedAt, kScores, kPutts, kCurrentHole] {
            d.removeObject(forKey: key)
        }
    }

    private func endRound() {
        isRoundActive = false
        connector.send([
            "scores": scores,
            "putts": putts,
            "currentHole": currentHole,
            "isActive": false,
        ])
        clearDefaults()
    }
}

// MARK: - Watch Connectivity Helper
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

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        // Once activated, replay any previously delivered application
        // context so a cold-launched Watch app picks up an in-progress
        // round without needing a fresh Phone push.
        let context = session.receivedApplicationContext
        if !context.isEmpty {
            DispatchQueue.main.async {
                self.onDataReceived?(context)
            }
        }
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        DispatchQueue.main.async {
            self.onDataReceived?(message)
        }
    }

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        DispatchQueue.main.async {
            self.onDataReceived?(applicationContext)
        }
    }
}
