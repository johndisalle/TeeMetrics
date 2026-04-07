// MARK: - Achievements View
// Beautiful grid of earned and locked achievements

import SwiftUI
import SwiftData

struct AchievementsView: View {
    @Query(sort: \GolfRound.date, order: .reverse) private var rounds: [GolfRound]

    private var earnedAchievements: [Achievement] {
        AchievementsManager.evaluateAchievements(rounds: rounds)
    }

    private var earnedSet: Set<String> {
        Set(earnedAchievements.map(\.rawValue))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Progress header
                HStack {
                    VStack(alignment: .leading) {
                        Text("\(earnedAchievements.count)/\(Achievement.allCases.count)")
                            .font(.title.bold())
                        Text("Achievements Unlocked")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    CircularProgressView(progress: Double(earnedAchievements.count) / Double(Achievement.allCases.count))
                        .frame(width: 56, height: 56)
                }
                .padding()
                .background(Theme.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 14))

                // Achievement grid
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(Achievement.allCases) { achievement in
                        let earned = earnedSet.contains(achievement.rawValue)
                        AchievementCard(achievement: achievement, isEarned: earned)
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Achievements")
    }
}

struct AchievementCard: View {
    let achievement: Achievement
    let isEarned: Bool

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: achievement.icon)
                .font(.title2)
                .foregroundStyle(isEarned ? achievementColor : .gray.opacity(0.3))
                .frame(width: 44, height: 44)
                .background(isEarned ? achievementColor.opacity(0.15) : Color.gray.opacity(0.05))
                .clipShape(Circle())

            Text(achievement.rawValue)
                .font(.caption.bold())
                .multilineTextAlignment(.center)
                .lineLimit(2)

            Text(achievement.description)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .padding(.horizontal, 8)
        .background(Theme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .opacity(isEarned ? 1 : 0.5)
        .shadow(color: isEarned ? achievementColor.opacity(0.15) : .clear, radius: 6, y: 2)
    }

    private var achievementColor: Color {
        switch achievement.color {
        case "gold": return Theme.accent
        case "silver": return .gray
        default: return Theme.primary
        }
    }
}

// MARK: - Circular Progress
struct CircularProgressView: View {
    let progress: Double

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.gray.opacity(0.15), lineWidth: 5)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(Theme.primary, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut, value: progress)
            Text("\(Int(progress * 100))%")
                .font(.caption2.bold())
        }
    }
}
