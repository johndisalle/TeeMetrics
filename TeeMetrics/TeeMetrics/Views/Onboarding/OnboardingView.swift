// MARK: - Onboarding View
// Welcome flow: golf-green gradient, animated flag, name & handicap entry

import SwiftUI
import SwiftData

struct OnboardingView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    @State private var currentPage = 0
    @State private var name = ""
    @State private var handicap = ""
    @State private var flagOffset: CGFloat = -20
    @State private var showFlag = false

    var body: some View {
        ZStack {
            Theme.golfGradient.ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                // MARK: - Animated Flag
                Image(systemName: "flag.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(Theme.accent)
                    .offset(y: flagOffset)
                    .opacity(showFlag ? 1 : 0)
                    .onAppear {
                        withAnimation(.easeOut(duration: 0.8)) {
                            showFlag = true
                            flagOffset = 0
                        }
                    }

                // MARK: - Welcome Text
                VStack(spacing: 8) {
                    Text("TeeMetrics")
                        .font(.largeTitle.bold())
                        .foregroundStyle(.white)
                    Text("Golf Stats Tracker & Round Analyzer")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.8))
                }

                Spacer()

                // MARK: - Input Fields
                VStack(spacing: 16) {
                    TextField("Your Name", text: $name)
                        .textFieldStyle(.roundedBorder)
                        .textContentType(.name)
                        .autocorrectionDisabled()
                        .padding(.horizontal)

                    TextField("Handicap Index (optional)", text: $handicap)
                        .textFieldStyle(.roundedBorder)
                        .keyboardType(.decimalPad)
                        .padding(.horizontal)
                }
                .padding()
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal)

                // MARK: - Get Started Button
                Button {
                    completeOnboarding()
                } label: {
                    Text("Get Started")
                        .font(.headline)
                        .foregroundStyle(Theme.primary)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Theme.accent)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .padding(.horizontal, 32)
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                .opacity(name.trimmingCharacters(in: .whitespaces).isEmpty ? 0.5 : 1)

                Spacer()
            }
            .padding()
        }
    }

    private func completeOnboarding() {
        Haptics.success()

        let golfer = Golfer(
            name: name.trimmingCharacters(in: .whitespaces),
            handicapIndex: Double(handicap) ?? 0
        )
        modelContext.insert(golfer)

        // Create default bag
        let bag = Bag.createDefault()
        modelContext.insert(bag)
        golfer.defaultBagID = bag.id

        hasCompletedOnboarding = true
    }
}
