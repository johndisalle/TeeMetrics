// MARK: - Animation Extensions & Micro-Interactions
// Smooth transitions, spring animations, and view modifiers

import SwiftUI

// MARK: - Slide In Modifier
struct SlideIn: ViewModifier {
    @State private var appeared = false
    let delay: Double

    func body(content: Content) -> some View {
        content
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 16)
            .onAppear {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(delay)) {
                    appeared = true
                }
            }
    }
}

extension View {
    func slideIn(delay: Double = 0) -> some View {
        modifier(SlideIn(delay: delay))
    }
}

// MARK: - Bounce Tap Modifier
struct BounceTap: ViewModifier {
    @State private var pressed = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(pressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: pressed)
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in pressed = true }
                    .onEnded { _ in pressed = false }
            )
    }
}

extension View {
    func bounceTap() -> some View {
        modifier(BounceTap())
    }
}

// MARK: - Count Up Animation
struct AnimatedNumber: View {
    let value: Int
    @State private var displayValue: Int = 0

    var body: some View {
        Text("\(displayValue)")
            .onAppear { animateValue() }
            .onChange(of: value) { _, _ in animateValue() }
    }

    private func animateValue() {
        withAnimation(.easeOut(duration: 0.5)) {
            displayValue = value
        }
    }
}

// MARK: - Shimmer Loading Effect
struct Shimmer: ViewModifier {
    @State private var phase: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .overlay(
                LinearGradient(
                    colors: [.clear, .white.opacity(0.1), .clear],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .offset(x: phase)
                .onAppear {
                    withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                        phase = 300
                    }
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Achievement Unlock Animation
struct AchievementUnlockOverlay: View {
    let achievement: Achievement
    @Binding var isPresented: Bool

    var body: some View {
        if isPresented {
            VStack(spacing: 16) {
                Image(systemName: achievement.icon)
                    .font(.system(size: 48))
                    .foregroundStyle(Theme.accent)
                    .transition(.scale.combined(with: .opacity))

                Text("Achievement Unlocked!")
                    .font(.headline)
                    .foregroundStyle(.white)

                Text(achievement.rawValue)
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)

                Text(achievement.description)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
            }
            .padding(32)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .shadow(radius: 20)
            .transition(.scale.combined(with: .opacity))
            .onAppear {
                Haptics.success()
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    withAnimation { isPresented = false }
                }
            }
        }
    }
}
