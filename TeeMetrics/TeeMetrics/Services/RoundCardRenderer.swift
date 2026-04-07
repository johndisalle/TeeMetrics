// MARK: - Round Card Renderer
// Generates beautiful shareable round summary images
// Supports standard share card and Instagram-story-sized format

import SwiftUI
import UIKit

@MainActor
enum RoundCardRenderer {

    // MARK: - Standard Share Card (1080x1350, 4:5 ratio for IG feed)
    static func renderShareCard(round: GolfRound) -> UIImage {
        let view = ShareCardView(round: round)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 3.0
        return renderer.uiImage ?? UIImage()
    }

    // MARK: - Story Card (1080x1920, 9:16 ratio for IG stories)
    static func renderStoryCard(round: GolfRound) -> UIImage {
        let view = StoryCardView(round: round)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 3.0
        return renderer.uiImage ?? UIImage()
    }
}

// MARK: - Share Card View (4:5 feed format)
struct ShareCardView: View {
    let round: GolfRound

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 8) {
                Image(systemName: "flag.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(Color(red: 0.93, green: 0.79, blue: 0.39))

                Text("TeeMetrics")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.6))
            }
            .padding(.top, 32)

            Spacer().frame(height: 24)

            // Course & Date
            VStack(spacing: 4) {
                Text(round.course?.name ?? "Unknown Course")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                Text(round.date.formatted(date: .long, time: .omitted))
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.6))
            }

            Spacer().frame(height: 28)

            // Big Score
            ZStack {
                Circle()
                    .fill(.white.opacity(0.1))
                    .frame(width: 120, height: 120)
                VStack(spacing: 2) {
                    Text("\(round.totalScore)")
                        .font(.system(size: 52, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text(round.scoreToParString)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(scoreAccentColor)
                }
            }

            Spacer().frame(height: 28)

            // Front / Back
            HStack(spacing: 32) {
                scorePill("FRONT", value: "\(round.frontNine)")
                scorePill("BACK", value: "\(round.backNine)")
            }

            Spacer().frame(height: 20)

            // Stats Row
            HStack(spacing: 24) {
                statColumn("Putts", value: "\(round.totalPutts)")
                divider
                statColumn("FW%", value: String(format: "%.0f%%", round.fairwayPercentage))
                divider
                statColumn("GIR%", value: String(format: "%.0f%%", round.girPercentage))
            }
            .padding(.horizontal, 24)

            Spacer().frame(height: 24)

            // Scorecard mini
            miniScorecard

            Spacer()

            // Footer
            Text("teemetrics.app")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.3))
                .padding(.bottom, 20)
        }
        .frame(width: 360, height: 450)
        .background(
            LinearGradient(
                colors: [Color(red: 0.08, green: 0.25, blue: 0.17), Color(red: 0.14, green: 0.38, blue: 0.26)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }

    private var scoreAccentColor: Color {
        let diff = round.scoreToPar
        if diff < 0 { return .green }
        if diff == 0 { return Color(red: 0.93, green: 0.79, blue: 0.39) }
        return .red.opacity(0.8)
    }

    private func scorePill(_ label: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.white.opacity(0.5))
            Text(value)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
        }
    }

    private func statColumn(_ label: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.white.opacity(0.5))
        }
    }

    private var divider: some View {
        Rectangle()
            .fill(.white.opacity(0.15))
            .frame(width: 1, height: 36)
    }

    private var miniScorecard: some View {
        let entries = round.holeEntries.sorted { $0.holeNumber < $1.holeNumber }
        return VStack(spacing: 4) {
            HStack(spacing: 2) {
                ForEach(entries.prefix(9)) { e in
                    miniHoleCell(e)
                }
            }
            HStack(spacing: 2) {
                ForEach(entries.suffix(9)) { e in
                    miniHoleCell(e)
                }
            }
        }
        .padding(.horizontal, 16)
    }

    private func miniHoleCell(_ entry: HoleEntry) -> some View {
        let diff = entry.scoreToPar
        let bg: Color = diff <= -2 ? .yellow.opacity(0.3) :
                         diff == -1 ? .red.opacity(0.25) :
                         diff == 0 ? .clear :
                         diff == 1 ? .blue.opacity(0.2) : .purple.opacity(0.2)
        return Text("\(entry.score)")
            .font(.system(size: 11, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .frame(width: 28, height: 22)
            .background(bg)
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}

// MARK: - Story Card View (9:16 format)
struct StoryCardView: View {
    let round: GolfRound

    var body: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 80)

            Image(systemName: "flag.fill")
                .font(.system(size: 48))
                .foregroundStyle(Color(red: 0.93, green: 0.79, blue: 0.39))

            Spacer().frame(height: 16)

            Text("TeeMetrics")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.5))

            Spacer().frame(height: 40)

            Text(round.course?.name ?? "Unknown Course")
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Text(round.date.formatted(date: .long, time: .omitted))
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.5))
                .padding(.top, 4)

            Spacer().frame(height: 48)

            // Giant score
            ZStack {
                Circle()
                    .fill(.white.opacity(0.08))
                    .frame(width: 160, height: 160)
                VStack(spacing: 4) {
                    Text("\(round.totalScore)")
                        .font(.system(size: 72, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text(round.scoreToParString)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(round.scoreToPar <= 0 ? .green : .red.opacity(0.8))
                }
            }

            Spacer().frame(height: 40)

            // Stats
            HStack(spacing: 32) {
                storyStatPill("FRONT", "\(round.frontNine)")
                storyStatPill("BACK", "\(round.backNine)")
                storyStatPill("PUTTS", "\(round.totalPutts)")
            }

            Spacer().frame(height: 24)

            HStack(spacing: 32) {
                storyStatPill("FW%", String(format: "%.0f%%", round.fairwayPercentage))
                storyStatPill("GIR%", String(format: "%.0f%%", round.girPercentage))
                storyStatPill("AVG P", String(format: "%.1f", round.averagePutts))
            }

            Spacer()

            Text("teemetrics.app")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white.opacity(0.25))
                .padding(.bottom, 60)
        }
        .frame(width: 360, height: 640)
        .background(
            LinearGradient(
                colors: [Color(red: 0.06, green: 0.2, blue: 0.14), Color(red: 0.12, green: 0.35, blue: 0.24)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    private func storyStatPill(_ label: String, _ value: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text(label)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.white.opacity(0.4))
        }
    }
}

// MARK: - Share Sheet Helper
struct RoundShareSheet: View {
    let round: GolfRound
    @State private var cardImage: UIImage?
    @State private var storyImage: UIImage?
    @State private var selectedFormat = 0

    var body: some View {
        VStack(spacing: 16) {
            Picker("Format", selection: $selectedFormat) {
                Text("Feed (4:5)").tag(0)
                Text("Story (9:16)").tag(1)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)

            if let image = selectedFormat == 0 ? cardImage : storyImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(radius: 8)
                    .padding(.horizontal, 32)

                ShareLink(item: Image(uiImage: image), preview: SharePreview("My Round at \(round.course?.name ?? "the course")", image: Image(uiImage: image))) {
                    Label("Share", systemImage: "square.and.arrow.up")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Theme.primary)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .padding(.horizontal, 24)
            }
        }
        .padding(.top)
        .task {
            cardImage = RoundCardRenderer.renderShareCard(round: round)
            storyImage = RoundCardRenderer.renderStoryCard(round: round)
        }
    }
}
