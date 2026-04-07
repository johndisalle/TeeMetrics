// MARK: - Goal Model
// User-defined goals with progress tracking

import Foundation
import SwiftData

@Model
final class Goal {
    var id: UUID
    var title: String
    var goalType: String // score, putts, fairways, gir, rounds, handicap
    var targetValue: Double
    var currentValue: Double
    var deadline: Date
    var isCompleted: Bool
    var createdAt: Date

    var progress: Double {
        guard targetValue != 0 else { return 0 }
        // For score/handicap, lower is better
        if goalType == "score" || goalType == "handicap" {
            // If starting at 90 targeting 80, progress = how close to 80
            guard currentValue > 0 else { return 0 }
            return min(1.0, max(0, 1.0 - (currentValue - targetValue) / currentValue))
        }
        return min(1.0, currentValue / targetValue)
    }

    var progressPercentage: Int {
        Int(progress * 100)
    }

    var isExpired: Bool {
        Date() > deadline && !isCompleted
    }

    var daysRemaining: Int {
        max(0, Calendar.current.dateComponents([.day], from: Date(), to: deadline).day ?? 0)
    }

    var goalTypeIcon: String {
        switch goalType {
        case "score": return "number.circle.fill"
        case "putts": return "circle.fill"
        case "fairways": return "leaf.fill"
        case "gir": return "target"
        case "rounds": return "flag.checkered"
        case "handicap": return "chart.line.downtrend.xyaxis"
        default: return "star.fill"
        }
    }

    init(
        title: String,
        goalType: String,
        targetValue: Double,
        deadline: Date
    ) {
        self.id = UUID()
        self.title = title
        self.goalType = goalType
        self.targetValue = targetValue
        self.currentValue = 0
        self.deadline = deadline
        self.isCompleted = false
        self.createdAt = Date()
    }
}
