// MARK: - Onboarding View
// Premium welcome flow with layered depth, glass morphism, and staggered reveals

import SwiftUI
import SwiftData

struct OnboardingView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    @State private var name = ""
    @State private var handicap = ""
    @State private var flagOffset: CGFloat = -40
    @State private var showBranding = false
    @State private var showFeatures = false
    @State private var showForm = false
    @State private var showButton = false
    @State private var pulseFlag = false

    var body: some View {
        ZStack {
            // MARK: - Background layers
            backgroundGradient
            backgroundOrbs

            VStack(spacing: 0) {
                Spacer()

                // MARK: - Logo & Branding
                VStack(spacing: 16) {
                    // Animated flag with glow
                    ZStack {
                        // Glow behind flag
                        Circle()
                            .fill(Theme.accent.opacity(0.15))
                            .frame(width: 100, height: 100)
                            .blur(radius: 20)
                            .scaleEffect(pulseFlag ? 1.2 : 0.8)

                        Image(systemName: "flag.fill")
                            .font(.system(size: 56))
                            .foregroundStyle(Theme.accent)
                            .shadow(color: Theme.accent.opacity(0.4), radius: 12, y: 4)
                    }
                    .offset(y: flagOffset)
                    .opacity(showBranding ? 1 : 0)

                    VStack(spacing: 6) {
                        Text("TeeMetrics")
                            .font(.system(size: 38, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)

                        Text("Track Every Shot. Own Your Game.")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(.white.opacity(0.55))
                    }
                    .opacity(showBranding ? 1 : 0)
                    .offset(y: showBranding ? 0 : 12)
                }

                Spacer().frame(height: 24)

                // MARK: - Feature chips
                HStack(spacing: 10) {
                    featureChip(icon: "bolt.fill", text: "Offline First")
                    featureChip(icon: "lock.fill", text: "100% Private")
                    featureChip(icon: "applewatch", text: "Apple Watch")
                }
                .opacity(showFeatures ? 1 : 0)
                .offset(y: showFeatures ? 0 : 8)

                Spacer()

                // MARK: - Input Card (glass morphism)
                VStack(spacing: 16) {
                    // Name field
                    VStack(alignment: .leading, spacing: 5) {
                        Text("YOUR NAME")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white.opacity(0.45))
                            .kerning(1.2)
                        HStack(spacing: 10) {
                            Image(systemName: "person.fill")
                                .font(.system(size: 14))
                                .foregroundStyle(.white.opacity(0.35))
                            TextField("", text: $name, prompt: Text("Enter your name").foregroundStyle(.white.opacity(0.3)))
                                .textContentType(.name)
                                .autocorrectionDisabled()
                                .foregroundStyle(.white)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 13)
                        .background(.white.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(.white.opacity(0.1), lineWidth: 1)
                        )
                    }

                    // Handicap field
                    VStack(alignment: .leading, spacing: 5) {
                        Text("HANDICAP INDEX")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white.opacity(0.45))
                            .kerning(1.2)
                        HStack(spacing: 10) {
                            Image(systemName: "number")
                                .font(.system(size: 14))
                                .foregroundStyle(.white.opacity(0.35))
                            TextField("", text: $handicap, prompt: Text("Optional").foregroundStyle(.white.opacity(0.3)))
                                .keyboardType(.decimalPad)
                                .foregroundStyle(.white)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 13)
                        .background(.white.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(.white.opacity(0.1), lineWidth: 1)
                        )
                    }
                }
                .padding(20)
                .background(.ultraThinMaterial.opacity(0.4))
                .background(.white.opacity(0.04))
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(.white.opacity(0.08), lineWidth: 1)
                )
                .padding(.horizontal, 24)
                .opacity(showForm ? 1 : 0)
                .offset(y: showForm ? 0 : 24)

                Spacer().frame(height: 24)

                // MARK: - CTA Button
                Button {
                    completeOnboarding()
                } label: {
                    HStack(spacing: 8) {
                        Text("Get Started")
                            .font(.system(size: 17, weight: .semibold))
                        Image(systemName: "arrow.right")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundStyle(Color(red: 0.08, green: 0.22, blue: 0.15))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 17)
                    .background(
                        LinearGradient(
                            colors: [.white, .white.opacity(0.9)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .shadow(color: .white.opacity(0.15), radius: 12, y: 4)
                }
                .padding(.horizontal, 24)
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                .opacity(name.trimmingCharacters(in: .whitespaces).isEmpty ? 0.4 : 1)
                .opacity(showButton ? 1 : 0)
                .offset(y: showButton ? 0 : 16)

                Spacer().frame(height: 14)

                // MARK: - Legal
                HStack(spacing: 14) {
                    Link("Terms of Service", destination: AppURLs.terms)
                    Text("·").foregroundStyle(.white.opacity(0.25))
                    Link("Privacy Policy", destination: AppURLs.privacy)
                }
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.35))
                .opacity(showButton ? 1 : 0)

                Spacer().frame(height: 28)
            }
        }
        .onAppear { startAnimations() }
    }

    // MARK: - Background Gradient (deeper, richer)
    private var backgroundGradient: some View {
        LinearGradient(
            stops: [
                .init(color: Color(red: 0.06, green: 0.18, blue: 0.12), location: 0),
                .init(color: Color(red: 0.10, green: 0.28, blue: 0.19), location: 0.4),
                .init(color: Color(red: 0.08, green: 0.24, blue: 0.16), location: 0.7),
                .init(color: Color(red: 0.05, green: 0.15, blue: 0.10), location: 1),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    // MARK: - Floating Background Orbs
    private var backgroundOrbs: some View {
        ZStack {
            Circle()
                .fill(Theme.accent.opacity(0.04))
                .frame(width: 300, height: 300)
                .blur(radius: 60)
                .offset(x: -80, y: -200)

            Circle()
                .fill(Color.green.opacity(0.06))
                .frame(width: 250, height: 250)
                .blur(radius: 50)
                .offset(x: 100, y: 300)

            Circle()
                .fill(Theme.accent.opacity(0.03))
                .frame(width: 200, height: 200)
                .blur(radius: 40)
                .offset(x: 120, y: -100)
        }
        .ignoresSafeArea()
    }

    // MARK: - Feature Chip
    private func featureChip(icon: String, text: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))
            Text(text)
                .font(.system(size: 11, weight: .semibold))
        }
        .foregroundStyle(.white.opacity(0.55))
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(.white.opacity(0.07))
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(.white.opacity(0.08), lineWidth: 1)
        )
    }

    // MARK: - Animation Sequence
    private func startAnimations() {
        withAnimation(.spring(response: 0.8, dampingFraction: 0.7)) {
            showBranding = true
            flagOffset = 0
        }
        withAnimation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.15)) {
            pulseFlag = true
        }
        withAnimation(.easeOut(duration: 0.5).delay(0.3)) {
            showFeatures = true
        }
        withAnimation(.easeOut(duration: 0.5).delay(0.5)) {
            showForm = true
        }
        withAnimation(.easeOut(duration: 0.5).delay(0.7)) {
            showButton = true
        }
    }

    // MARK: - Complete Onboarding
    private func completeOnboarding() {
        Haptics.success()

        let golfer = Golfer(
            name: name.trimmingCharacters(in: .whitespaces),
            handicapIndex: Double(handicap) ?? 0
        )
        modelContext.insert(golfer)

        let bag = Bag.createDefault()
        modelContext.insert(bag)
        golfer.defaultBagID = bag.id

        withAnimation(.easeInOut(duration: 0.3)) {
            hasCompletedOnboarding = true
        }
    }
}
