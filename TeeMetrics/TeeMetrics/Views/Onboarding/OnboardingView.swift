// MARK: - Onboarding View
// Welcome flow: golf-green gradient, animated flag, name & handicap entry

import SwiftUI
import SwiftData

struct OnboardingView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    @State private var name = ""
    @State private var handicap = ""
    @State private var flagOffset: CGFloat = -30
    @State private var showContent = false
    @State private var showFields = false

    var body: some View {
        ZStack {
            Theme.golfGradient.ignoresSafeArea()

            // Subtle background pattern
            VStack {
                Spacer()
                Image(systemName: "circle.grid.3x3.fill")
                    .font(.system(size: 200))
                    .foregroundStyle(.white.opacity(0.03))
                    .rotationEffect(.degrees(15))
            }
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // MARK: - Animated Flag
                Image(systemName: "flag.fill")
                    .font(.system(size: 72))
                    .foregroundStyle(Theme.accent)
                    .offset(y: flagOffset)
                    .opacity(showContent ? 1 : 0)
                    .shadow(color: .black.opacity(0.2), radius: 8, y: 4)

                Spacer().frame(height: 24)

                // MARK: - Welcome Text
                VStack(spacing: 8) {
                    Text("TeeMetrics")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text("Golf Stats Tracker & Round Analyzer")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.7))
                }
                .opacity(showContent ? 1 : 0)
                .offset(y: showContent ? 0 : 10)

                Spacer().frame(height: 16)

                // MARK: - Feature Pills
                HStack(spacing: 12) {
                    featurePill("Offline First")
                    featurePill("100% Private")
                    featurePill("Apple Watch")
                }
                .opacity(showContent ? 1 : 0)
                .offset(y: showContent ? 0 : 10)

                Spacer()

                // MARK: - Input Fields
                VStack(spacing: 14) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("YOUR NAME")
                            .font(.caption.bold())
                            .foregroundStyle(.white.opacity(0.6))
                        TextField("", text: $name, prompt: Text("Enter your name").foregroundStyle(.white.opacity(0.4)))
                            .textContentType(.name)
                            .autocorrectionDisabled()
                            .font(.body)
                            .foregroundStyle(.white)
                            .padding()
                            .background(.white.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("HANDICAP INDEX")
                            .font(.caption.bold())
                            .foregroundStyle(.white.opacity(0.6))
                        TextField("", text: $handicap, prompt: Text("Optional").foregroundStyle(.white.opacity(0.4)))
                            .keyboardType(.decimalPad)
                            .font(.body)
                            .foregroundStyle(.white)
                            .padding()
                            .background(.white.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
                .padding(.horizontal, 28)
                .opacity(showFields ? 1 : 0)
                .offset(y: showFields ? 0 : 20)

                Spacer().frame(height: 28)

                // MARK: - Get Started Button
                Button {
                    completeOnboarding()
                } label: {
                    Text("Get Started")
                        .font(.headline)
                        .foregroundStyle(Theme.primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
                }
                .padding(.horizontal, 28)
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                .opacity(name.trimmingCharacters(in: .whitespaces).isEmpty ? 0.5 : 1)
                .opacity(showFields ? 1 : 0)

                // MARK: - Legal Links
                HStack(spacing: 16) {
                    Link("Terms of Service", destination: AppURLs.terms)
                    Text("·").foregroundStyle(.white.opacity(0.4))
                    Link("Privacy Policy", destination: AppURLs.privacy)
                }
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.5))
                .padding(.bottom, 16)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.7)) {
                showContent = true
                flagOffset = 0
            }
            withAnimation(.easeOut(duration: 0.6).delay(0.4)) {
                showFields = true
            }
        }
    }

    // MARK: - Feature Pill
    private func featurePill(_ text: String) -> some View {
        Text(text)
            .font(.caption2.bold())
            .foregroundStyle(.white.opacity(0.7))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(.white.opacity(0.1))
            .clipShape(Capsule())
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
