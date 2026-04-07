// MARK: - Watch Round View
// Simplified per-hole scoring with phone sync via shared UserDefaults
// Quick score entry, putts, running total

import SwiftUI
import WatchConnectivity

struct WatchRoundView: View {
    @StateObject private var connector = WatchConnector()
    @State private var currentHole = 1
    @State private var scores: [Int] = Array(repeating: 0, count: 18)
    @State private var putts: [Int] = Array(repeating: 0, count: 18)
    @State private var pars: [Int] = Array(repeating: 4, count: 18)
    @State private var courseName: String = "TeeMetrics"
    @State private var isRoundActive = false

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
                .navigationTitle("H\(currentHole)")
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("End") {
                            endRound()
                        }
                        .foregroundStyle(.red)
                    }
                }
            } else {
                // Start screen
                VStack(spacing: 12) {
                    Image(systemName: "flag.fill")
                        .font(.title)
                        .foregroundStyle(.green)
                    Text("TeeMetrics")
                        .font(.headline)
                    Text("Start scoring when you begin your round on iPhone")
                        .font(.caption2)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)

                    Button("Quick Round") {
                        startQuickRound()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                }
                .padding()
            }
        }
        .onAppear {
            connector.onDataReceived = { data in
                handlePhoneData(data)
            }
        }
    }

    private func watchHoleView(hole: Int) -> some View {
        let idx = hole - 1
        return VStack(spacing: 4) {
            // Header
            HStack {
                Text("H\(hole)")
                    .font(.headline)
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
        .onChange(of: scores[idx]) { _, _ in syncToPhone() }
        .onChange(of: putts[idx]) { _, _ in syncToPhone() }
    }

    private func scoreColor(score: Int, par: Int) -> Color {
        guard score > 0 else { return .primary }
        let diff = score - par
        if diff <= -1 { return .red }
        if diff == 0 { return .green }
        return .primary
    }

    // MARK: - Phone Sync
    private func syncToPhone() {
        connector.send([
            "scores": scores,
            "putts": putts,
            "currentHole": currentHole,
        ])
    }

    private func handlePhoneData(_ data: [String: Any]) {
        if let p = data["pars"] as? [Int] { pars = p }
        if let name = data["courseName"] as? String { courseName = name }
        if let active = data["isActive"] as? Bool { isRoundActive = active }
    }

    private func startQuickRound() {
        isRoundActive = true
        scores = Array(repeating: 0, count: 18)
        putts = Array(repeating: 0, count: 18)
        currentHole = 1
    }

    private func endRound() {
        isRoundActive = false
        syncToPhone()
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

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {}

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        DispatchQueue.main.async {
            self.onDataReceived?(message)
        }
    }
}
