// MARK: - Post-Round Celebration Screen
// Confetti for PBs, animated stat reveal, share prompt
// The #1 emotional moment in the app — this drives shares and virality

import SwiftUI
import SwiftData

struct RoundCelebrationView: View {
    let round: GolfRound
    let isPersonalBest: Bool
    let previousBest: Int?
    let onDismiss: () -> Void

    @State private var showScore = false
    @State private var showStats = false
    @State private var showActions = false
    @State private var showConfetti = false
    @State private var showShareCard = false
    @State private var confettiPieces: [ConfettiPiece] = []

    var body: some View {
        ZStack {
            // Background
            Theme.golfGradient.ignoresSafeArea()

            // Confetti layer
            if showConfetti {
                ConfettiView(pieces: $confettiPieces)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }

            ScrollView {
                VStack(spacing: 0) {
                    Spacer().frame(height: 60)

                    // MARK: - Trophy / Flag Icon
                    ZStack {
                        Circle()
                            .fill(.white.opacity(0.1))
                            .frame(width: 100, height: 100)
                            .scaleEffect(showScore ? 1 : 0.3)
                            .opacity(showScore ? 1 : 0)

                        Image(systemName: isPersonalBest ? "trophy.fill" : "flag.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(isPersonalBest ? Theme.accent : .white)
                            .scaleEffect(showScore ? 1 : 0)
                            .rotationEffect(showScore ? .zero : .degrees(-30))
                    }
                    .animation(.spring(response: 0.6, dampingFraction: 0.6), value: showScore)

                    Spacer().frame(height: 16)

                    // MARK: - Headline
                    Text(isPersonalBest ? "NEW PERSONAL BEST!" : "Round Complete!")
                        .font(.system(size: isPersonalBest ? 22 : 20, weight: .bold, design: .rounded))
                        .foregroundStyle(isPersonalBest ? Theme.accent : .white)
                        .opacity(showScore ? 1 : 0)
                        .offset(y: showScore ? 0 : 10)
                        .animation(.easeOut(duration: 0.5).delay(0.2), value: showScore)

                    Spacer().frame(height: 8)

                    Text(round.course?.name ?? "")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.6))
                        .opacity(showScore ? 1 : 0)
                        .animation(.easeOut(duration: 0.5).delay(0.3), value: showScore)

                    Spacer().frame(height: 32)

                    // MARK: - Big Score
                    VStack(spacing: 4) {
                        Text("\(round.totalScore)")
                            .font(.system(size: 80, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .scaleEffect(showScore ? 1 : 0.5)
                            .opacity(showScore ? 1 : 0)

                        Text(round.scoreToParString)
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundStyle(scoreAccentColor)
                            .opacity(showScore ? 1 : 0)
                            .offset(y: showScore ? 0 : 10)

                        if isPersonalBest, let prev = previousBest {
                            Text("Previous best: \(prev)")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.5))
                                .padding(.top, 4)
                                .opacity(showScore ? 1 : 0)
                        }
                    }
                    .animation(.spring(response: 0.7, dampingFraction: 0.7).delay(0.4), value: showScore)

                    Spacer().frame(height: 36)

                    // MARK: - Animated Stats
                    VStack(spacing: 16) {
                        HStack(spacing: 20) {
                            celebrationStat("Front 9", value: "\(round.frontNine)", delay: 0)
                            celebrationDivider(delay: 0.05)
                            celebrationStat("Back 9", value: "\(round.backNine)", delay: 0.1)
                        }

                        HStack(spacing: 20) {
                            celebrationStat("Putts", value: "\(round.totalPutts)", delay: 0.15)
                            celebrationDivider(delay: 0.2)
                            celebrationStat("FW%", value: String(format: "%.0f%%", round.fairwayPercentage), delay: 0.25)
                            celebrationDivider(delay: 0.3)
                            celebrationStat("GIR%", value: String(format: "%.0f%%", round.girPercentage), delay: 0.35)
                        }
                    }
                    .padding(20)
                    .background(.white.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal, 24)
                    .opacity(showStats ? 1 : 0)
                    .offset(y: showStats ? 0 : 20)
                    .animation(.easeOut(duration: 0.5), value: showStats)

                    Spacer().frame(height: 16)

                    // MARK: - Highlights
                    VStack(spacing: 8) {
                        ForEach(highlights, id: \.self) { highlight in
                            HStack(spacing: 8) {
                                Image(systemName: "sparkle")
                                    .font(.caption)
                                    .foregroundStyle(Theme.accent)
                                Text(highlight)
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.7))
                            }
                        }
                    }
                    .opacity(showStats ? 1 : 0)
                    .animation(.easeOut(duration: 0.4).delay(0.3), value: showStats)

                    Spacer().frame(height: 36)

                    // MARK: - Action Buttons
                    VStack(spacing: 12) {
                        Button {
                            showShareCard = true
                        } label: {
                            HStack {
                                Image(systemName: "square.and.arrow.up")
                                Text("Share Round Card")
                            }
                            .font(.headline)
                            .foregroundStyle(Theme.primary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
                        }

                        Button {
                            onDismiss()
                        } label: {
                            Text("Done")
                                .font(.subheadline.bold())
                                .foregroundStyle(.white.opacity(0.7))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(.white.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                    }
                    .padding(.horizontal, 28)
                    .opacity(showActions ? 1 : 0)
                    .offset(y: showActions ? 0 : 20)
                    .animation(.easeOut(duration: 0.5), value: showActions)

                    Spacer().frame(height: 40)
                }
            }
        }
        .onAppear { startAnimationSequence() }
        .sheet(isPresented: $showShareCard) {
            NavigationStack {
                RoundShareSheet(round: round)
                    .navigationTitle("Share Round")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Done") { showShareCard = false }
                        }
                    }
            }
        }
    }

    // MARK: - Animation Sequence
    private func startAnimationSequence() {
        withAnimation { showScore = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            withAnimation { showStats = true }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.3) {
            withAnimation { showActions = true }
        }
        if isPersonalBest {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                showConfetti = true
                spawnConfetti()
                Haptics.success()
            }
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                Haptics.medium()
            }
        }
    }

    // MARK: - Score Color
    private var scoreAccentColor: Color {
        let diff = round.scoreToPar
        if diff < 0 { return .green }
        if diff == 0 { return Theme.accent }
        return .red.opacity(0.8)
    }

    // MARK: - Highlights
    private var highlights: [String] {
        var h: [String] = []
        let entries = round.holeEntries
        let birdies = entries.filter { $0.scoreToPar == -1 }.count
        let eagles = entries.filter { $0.scoreToPar <= -2 }.count
        let pars = entries.filter { $0.scoreToPar == 0 }.count

        if eagles > 0 { h.append("\(eagles) eagle\(eagles > 1 ? "s" : "")!") }
        if birdies > 0 { h.append("\(birdies) birdie\(birdies > 1 ? "s" : "")") }
        if pars > 0 { h.append("\(pars) par\(pars > 1 ? "s" : "")") }
        if round.totalPutts < 30 { h.append("Under 30 putts — nice putting!") }
        if round.fairwayPercentage >= 60 { h.append("60%+ fairways — great driving") }
        if round.girPercentage >= 50 { h.append("50%+ GIR — solid approach game") }

        return Array(h.prefix(4))
    }

    // MARK: - Stat Cell
    private func celebrationStat(_ label: String, value: String, delay: Double) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
    }

    private func celebrationDivider(delay: Double) -> some View {
        Rectangle()
            .fill(.white.opacity(0.15))
            .frame(width: 1, height: 36)
    }

    // MARK: - Confetti
    private func spawnConfetti() {
        confettiPieces = (0..<60).map { _ in
            ConfettiPiece(
                x: CGFloat.random(in: 0...UIScreen.main.bounds.width),
                y: CGFloat.random(in: -100...(-20)),
                color: [Color.red, .green, .blue, Theme.accent, .white, .orange, .purple].randomElement()!,
                rotation: Double.random(in: 0...360),
                scale: CGFloat.random(in: 0.4...1.0)
            )
        }
    }
}

// MARK: - Confetti Piece
struct ConfettiPiece: Identifiable {
    let id = UUID()
    var x: CGFloat
    var y: CGFloat
    let color: Color
    let rotation: Double
    let scale: CGFloat
}

// MARK: - Confetti View
struct ConfettiView: View {
    @Binding var pieces: [ConfettiPiece]
    @State private var animate = false

    var body: some View {
        ZStack {
            ForEach(pieces) { piece in
                RoundedRectangle(cornerRadius: 2)
                    .fill(piece.color)
                    .frame(width: 8 * piece.scale, height: 14 * piece.scale)
                    .rotationEffect(.degrees(animate ? piece.rotation + 360 : piece.rotation))
                    .position(
                        x: piece.x + (animate ? CGFloat.random(in: -40...40) : 0),
                        y: animate ? UIScreen.main.bounds.height + 100 : piece.y
                    )
                    .opacity(animate ? 0 : 1)
            }
        }
        .onAppear {
            withAnimation(.easeIn(duration: 3.0)) {
                animate = true
            }
        }
    }
}
