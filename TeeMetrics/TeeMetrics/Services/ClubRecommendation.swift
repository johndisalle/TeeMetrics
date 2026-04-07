// MARK: - Club Recommendation Engine
// "From 155 yards, your 7-iron averages 158. Hit it."

import Foundation
import SwiftData

struct ClubRecommendation: Identifiable {
    let id = UUID()
    let club: Club
    let avgDistance: Int
    let confidence: String // "High", "Medium", "Low"
    let delta: Int // how close avg is to target
}

@MainActor
enum ClubRecommendationEngine {

    // MARK: - Recommend club for a distance
    static func recommend(distance: Int, from bag: Bag?) -> [ClubRecommendation] {
        guard let bag else { return [] }
        let clubs = bag.sortedClubs.filter { $0.avgDistance > 0 && $0.clubType != "putter" }
        guard !clubs.isEmpty else { return [] }

        return clubs
            .map { club in
                let delta = abs(club.avgDistance - distance)
                let confidence: String
                if club.totalShots >= 10 { confidence = "High" }
                else if club.totalShots >= 3 { confidence = "Medium" }
                else { confidence = "Low" }
                return ClubRecommendation(club: club, avgDistance: club.avgDistance, confidence: confidence, delta: delta)
            }
            .sorted { $0.delta < $1.delta }
    }

    // MARK: - Top pick with description
    static func topPick(distance: Int, from bag: Bag?) -> String? {
        guard let top = recommend(distance: distance, from: bag).first else { return nil }
        let direction = top.club.avgDistance >= distance ? "carries" : "averages"
        return "From \(distance) yds, your \(top.club.name) \(direction) \(top.avgDistance). Hit it."
    }

    // MARK: - Smart suggestion based on hole info
    static func suggestForHole(holeInfo: HoleInfo?, shotNumber: Int, bag: Bag?) -> String? {
        guard let info = holeInfo, let bag else { return nil }
        if shotNumber == 1 {
            if info.par == 3 {
                return topPick(distance: info.yardage, from: bag)
            } else {
                // Tee shot — recommend driver or longest club
                if let driver = bag.sortedClubs.first(where: { $0.clubType == "driver" }) {
                    return "Tee shot: \(driver.name) (avg \(driver.avgDistance) yds)"
                }
            }
        }
        // Approach: estimate remaining distance
        let estimatedRemaining = shotNumber == 2 ? info.yardage / 2 : info.yardage / 3
        return topPick(distance: estimatedRemaining, from: bag)
    }
}
