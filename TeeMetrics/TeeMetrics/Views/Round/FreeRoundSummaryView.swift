// MARK: - FreeRoundSummaryView (Session C)
// Free-tier post-round summary — replaces the Pro `RoundCelebrationView`
// for non-Pro users finishing a round. No confetti, no share card, no
// stat reveal animation. Just a clean, satisfying score readout plus
// one fun stat picked from a priority list of what's actually available
// on this round.
//
// Pro users keep `RoundCelebrationView` (LiveRoundView branches on
// `SubscriptionManager.shared.isProUser`).

import SwiftUI

struct FreeRoundSummaryView: View {
    let round: GolfRound
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            VStack(spacing: 28) {
                Spacer()

                // Header — course name + date
                VStack(spacing: 6) {
                    Text(round.course?.name ?? "Round Complete")
                        .font(.title2.bold())
                        .foregroundStyle(Theme.text)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .padding(.horizontal, 24)
                    Text(round.date.shortFormatted)
                        .font(.subheadline)
                        .foregroundStyle(Theme.textMuted)
                }

                // Big score block
                VStack(spacing: 4) {
                    Text("\(round.totalScore)")
                        .font(.system(size: 84, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.text)
                        .contentTransition(.numericText())
                    Text(round.scoreToParString)
                        .font(.title3.bold())
                        .foregroundStyle(Theme.scoreColor(for: round.scoreToPar))
                }

                // One fun stat — picked from the priority list below.
                if let stat = funStat {
                    funStatCard(stat)
                }

                Spacer()

                Button {
                    onDismiss()
                } label: {
                    Text("Done")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Theme.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
        }
    }

    // MARK: - Fun stat picker
    /// Returns the first non-nil stat from this priority order:
    ///   1. Longest drive   — longest captured `Shot` whose `clubName`
    ///                        contains "Driver" (case-insensitive)
    ///   2. Best hole       — lowest scoreToPar across the round's
    ///                        scored hole entries
    ///   3. Total putts     — non-zero total putts
    ///   4. Pars or better  — count of holes with score <= par
    /// Each branch returns nil if its data isn't available, so we fall
    /// through automatically to the next option.
    private var funStat: (icon: String, title: String, value: String)? {
        if let drive = longestDrive() {
            return ("scope", "Longest Drive", "\(drive) yds")
        }
        if let best = bestHole() {
            return ("flag.fill", "Best Hole", best)
        }
        if round.totalPutts > 0 {
            return ("hockey.puck.fill", "Total Putts", "\(round.totalPutts)")
        }
        let pars = parsOrBetterCount()
        if pars > 0 {
            return ("checkmark.seal.fill", "Pars or Better", "\(pars)")
        }
        return nil
    }

    private func longestDrive() -> Int? {
        let drives = round.shots.filter { shot in
            guard let name = shot.clubName?.lowercased() else { return false }
            return name.contains("driver")
        }
        let yardages = drives.compactMap { $0.distanceYards }
        guard let max = yardages.max(), max > 0 else { return nil }
        return Int(max.rounded())
    }

    /// Returns "Hole N · {scoreLabel}" for the hole with the lowest
    /// score-to-par. Nil when no holes have been scored yet.
    private func bestHole() -> String? {
        let scored = round.holeEntries.filter { $0.score > 0 }
        guard let best = scored.min(by: { $0.scoreToPar < $1.scoreToPar }) else { return nil }
        return "Hole \(best.holeNumber) · \(best.scoreLabel)"
    }

    private func parsOrBetterCount() -> Int {
        round.holeEntries.filter { $0.score > 0 && $0.scoreToPar <= 0 }.count
    }

    private func funStatCard(_ stat: (icon: String, title: String, value: String)) -> some View {
        HStack(spacing: 14) {
            Image(systemName: stat.icon)
                .font(.title2)
                .foregroundStyle(Theme.primary)
                .frame(width: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(stat.title)
                    .font(.caption.bold())
                    .foregroundStyle(Theme.textMuted)
                    .textCase(.uppercase)
                Text(stat.value)
                    .font(.headline)
                    .foregroundStyle(Theme.text)
            }
            Spacer()
        }
        .padding(16)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal, 24)
    }
}
