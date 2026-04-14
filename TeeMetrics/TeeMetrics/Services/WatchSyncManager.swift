// MARK: - Watch Sync Manager (Phone side)
// Pushes the active round's tee + per-hole pars to the Apple Watch via
// WatchConnectivity. The Watch app needs the per-tee par array to score
// correctly on courses where pars vary by tee box.
//
// Transport: `updateApplicationContext` for the start payload (survives
// across Watch launches and is delivered automatically when the Watch
// becomes available). `sendMessage` is also attempted as a real-time
// nudge when the Watch is reachable, but is best-effort.

import Foundation
import WatchConnectivity

@MainActor
final class WatchSyncManager: NSObject {
    static let shared = WatchSyncManager()

    private override init() {
        super.init()
    }

    /// Activates the WCSession on iPhone. Safe to call multiple times.
    func activate() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        if session.delegate == nil {
            session.delegate = self
        }
        if session.activationState != .activated {
            session.activate()
        }
    }

    // MARK: - Round start

    /// Called from `NewRoundView.startRound()` after the GolfRound row is
    /// inserted. Pushes course name, tee name, and the per-hole par array
    /// derived from the active CourseTee (or HoleInfo as fallback).
    func sendRoundStart(round: GolfRound) {
        activate()
        let payload = buildStartPayload(round: round)
        push(payload)
    }

    /// Called from `LiveRoundView.finishRound()`. Tells the Watch the
    /// round is over so it can return to the idle "start on iPhone first"
    /// screen.
    func sendRoundEnd() {
        activate()
        push(["isActive": false])
    }

    // MARK: - Payload assembly

    private func buildStartPayload(round: GolfRound) -> [String: Any] {
        var payload: [String: Any] = [
            "isActive": true,
            "courseName": round.course?.name ?? "TeeMetrics",
            // Bump on every fresh start so the Watch can detect a new round
            // even if the course/tee name hasn't changed.
            "startedAt": Date().timeIntervalSince1970,
        ]

        let pars = perHolePars(for: round)
        payload["holePars"] = pars

        if let teeName = round.teeName, !teeName.isEmpty {
            payload["teeName"] = teeName
        }

        return payload
    }

    /// Returns an 18-element array of pars. Prefers the active tee's
    /// per-hole par when set, falling back to HoleInfo.par, then 4.
    private func perHolePars(for round: GolfRound) -> [Int] {
        let course = round.course
        let selectedTee: CourseTee? = {
            guard let teeName = round.teeName, let course else { return nil }
            return course.tee(named: teeName)
        }()
        let sortedHoles = (course?.holes ?? []).sorted { $0.holeNumber < $1.holeNumber }

        var pars: [Int] = []
        for i in 1...18 {
            let teeHolePar = selectedTee?.hole(number: i)?.par
            let infoPar = sortedHoles.first { $0.holeNumber == i }?.par
            pars.append(teeHolePar ?? infoPar ?? 4)
        }
        return pars
    }

    // MARK: - Transport

    private func push(_ payload: [String: Any]) {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        guard session.activationState == .activated else { return }

        // Persistent state transfer — delivered to the Watch on next wake.
        do {
            try session.updateApplicationContext(payload)
        } catch {
            // Non-fatal — sendMessage below is the real-time fallback.
        }

        // Real-time delivery if the Watch happens to be reachable right now.
        if session.isReachable {
            session.sendMessage(payload, replyHandler: nil, errorHandler: nil)
        }
    }
}

// MARK: - WCSessionDelegate

extension WatchSyncManager: WCSessionDelegate {
    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {}

    // iOS-only delegate methods — required to compile on the Phone target.
    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        // Re-activate so the next paired Watch session works.
        WCSession.default.activate()
    }
}
