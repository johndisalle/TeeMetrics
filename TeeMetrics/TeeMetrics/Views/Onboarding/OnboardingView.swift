// MARK: - Onboarding View
// Premium welcome with tight layout, glassmorphism, and post-signup walkthrough

import SwiftUI
import SwiftData

struct OnboardingView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    @State private var name = ""
    @State private var handicap = ""
    @State private var flagScale: CGFloat = 0.3
    @State private var showBranding = false
    @State private var showForm = false
    @State private var showButton = false
    @State private var showBagPicker = false
    @State private var selectedTemplate: BagTemplate = .standard
    @State private var showWalkthrough = false

    /// Foundation Session A — when true, the form is hidden and the
    /// goal-selection list takes its place. Single-tap on a goal row
    /// completes onboarding immediately (no separate "Next" button).
    @State private var showGoalStep = false

    var body: some View {
        ZStack {
            backgroundGradient
            backgroundOrbs

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    Spacer().frame(height: 80)

                    // MARK: - Logo (Foundation Session A: brighter yellow glow)
                    // The flag itself is the light source. A soft radial
                    // glow ~120pt across, yellow at ~40% opacity fading to
                    // transparent, sits behind the flag.
                    ZStack {
                        // Outer halo — the bigger, softer light wash.
                        RadialGradient(
                            colors: [
                                Color(red: 0.93, green: 0.79, blue: 0.39).opacity(0.40),
                                Color(red: 0.93, green: 0.79, blue: 0.39).opacity(0.0),
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 120
                        )
                        .frame(width: 240, height: 240)
                        .blendMode(.plusLighter)

                        // Inner concentrated bloom right under the flag.
                        Circle()
                            .fill(Theme.accent.opacity(0.30))
                            .frame(width: 90, height: 90)
                            .blur(radius: 22)

                        Image(systemName: "flag.fill")
                            .font(.system(size: 56))
                            .foregroundStyle(Theme.accent)
                            .shadow(color: Theme.accent.opacity(0.55), radius: 14, y: 2)
                            .shadow(color: Theme.accent.opacity(0.35), radius: 28, y: 0)
                    }
                    .scaleEffect(flagScale)
                    .opacity(showBranding ? 1 : 0)

                    Spacer().frame(height: 20)

                    // MARK: - Title
                    VStack(spacing: 6) {
                        Text("TeeMetrics")
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        // Foundation Session A — new tagline.
                        Text("Golf stats. No account. No ads. No nonsense.")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.white.opacity(0.55))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }
                    .opacity(showBranding ? 1 : 0)
                    .offset(y: showBranding ? 0 : 10)

                    Spacer().frame(height: 20)

                    // MARK: - Feature Chips
                    VStack(spacing: 8) {
                        HStack(spacing: 8) {
                            featureChip(icon: "bolt.fill", text: "Offline First")
                            featureChip(icon: "lock.fill", text: "100% Private")
                        }
                        HStack(spacing: 8) {
                            featureChip(icon: "mappin.and.ellipse", text: "660+ Courses")
                            featureChip(icon: "applewatch", text: "Apple Watch")
                        }
                    }
                    .opacity(showBranding ? 1 : 0)

                    Spacer().frame(height: 32)

                    if showGoalStep {
                        // MARK: - Goal Step (Foundation Session A)
                        // Replaces the form + CTA once the user advances.
                        // One-tap select-and-advance — no confirmation.
                        goalSelectionCard
                            .padding(.horizontal, 20)
                            .transition(.opacity.combined(with: .move(edge: .trailing)))
                    } else {

                    // MARK: - Input Card
                    VStack(spacing: 18) {
                        // Name
                        inputField(
                            label: "YOUR NAME",
                            icon: "person.fill",
                            placeholder: "Enter your name",
                            text: $name,
                            keyboard: .default
                        )

                        // Handicap + Bag (side by side)
                        HStack(spacing: 12) {
                            inputField(
                                label: "HANDICAP",
                                icon: "number",
                                placeholder: "Optional",
                                text: $handicap,
                                keyboard: .decimalPad
                            )

                            VStack(alignment: .leading, spacing: 6) {
                                Text("BAG SETUP")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(.white.opacity(0.4))
                                    .kerning(1)
                                Button {
                                    showBagPicker = true
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: selectedTemplate.icon)
                                            .font(.system(size: 13))
                                        Text(selectedTemplate.rawValue)
                                            .font(.system(size: 14))
                                        Spacer()
                                        Image(systemName: "chevron.down")
                                            .font(.system(size: 10))
                                            .foregroundStyle(.white.opacity(0.3))
                                    }
                                    .foregroundStyle(.white.opacity(0.65))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 12)
                                    .background(.white.opacity(0.08))
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(.white.opacity(0.08), lineWidth: 1)
                                    )
                                }
                            }
                        }
                    }
                    .padding(20)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(.ultraThinMaterial.opacity(0.5))
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(.white.opacity(0.03))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(.white.opacity(0.1), lineWidth: 1)
                            )
                    )
                    .padding(.horizontal, 20)
                    .opacity(showForm ? 1 : 0)
                    .offset(y: showForm ? 0 : 20)

                    Spacer().frame(height: 24)

                    // MARK: - CTA — advances to the goal step
                    Button {
                        Haptics.selection()
                        withAnimation(.easeInOut(duration: 0.35)) {
                            showGoalStep = true
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Text("Continue")
                                .font(.system(size: 17, weight: .bold))
                            Image(systemName: "arrow.right")
                                .font(.system(size: 14, weight: .bold))
                        }
                        .foregroundStyle(Color(red: 0.06, green: 0.18, blue: 0.12))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 17)
                        .background(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .shadow(color: .white.opacity(0.12), radius: 12, y: 4)
                    }
                    .padding(.horizontal, 20)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                    .opacity(name.trimmingCharacters(in: .whitespaces).isEmpty ? 0.35 : 1)
                    .opacity(showButton ? 1 : 0)
                    .offset(y: showButton ? 0 : 12)

                    Spacer().frame(height: 16)

                    // MARK: - Legal
                    HStack(spacing: 14) {
                        Link("Terms of Service", destination: AppURLs.terms)
                        Text("·").foregroundStyle(.white.opacity(0.2))
                        Link("Privacy Policy", destination: AppURLs.privacy)
                    }
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.3))
                    .opacity(showButton ? 1 : 0)

                    Spacer().frame(height: 32)
                    } // end !showGoalStep else
                }
            }
            .onTapGesture {
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            }
        }
        .onAppear { startAnimations() }
        .sheet(isPresented: $showBagPicker) {
            OnboardingBagSheet(selectedTemplate: $selectedTemplate)
        }
        .fullScreenCover(isPresented: $showWalkthrough) {
            WelcomeWalkthroughView {
                withAnimation { hasCompletedOnboarding = true }
            }
        }
    }

    // MARK: - Input Field
    private func inputField(label: String, icon: String, placeholder: String, text: Binding<String>, keyboard: UIKeyboardType) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.white.opacity(0.4))
                .kerning(1)
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.3))
                TextField("", text: text, prompt: Text(placeholder).foregroundStyle(.white.opacity(0.25)))
                    .foregroundStyle(.white)
                    .font(.system(size: 15))
                    .keyboardType(keyboard)
                    .textContentType(keyboard == .default ? .name : nil)
                    .autocorrectionDisabled()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .background(.white.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(.white.opacity(0.08), lineWidth: 1)
            )
        }
    }

    // MARK: - Background (Foundation Session A: lighter splash radial)
    /// Two-stop radial gradient: #1F4A32 at center, #0D2419 at edges.
    /// Roughly 35% lighter at center than the prior linear gradient so
    /// the yellow flag glow has somewhere bright to bloom into.
    private var backgroundGradient: some View {
        RadialGradient(
            stops: [
                .init(color: Color(red: 0.122, green: 0.290, blue: 0.196), location: 0.0),  // #1F4A32
                .init(color: Color(red: 0.051, green: 0.141, blue: 0.098), location: 1.0),  // #0D2419
            ],
            center: .center,
            startRadius: 40,
            endRadius: 700
        )
        .ignoresSafeArea()
    }

    private var backgroundOrbs: some View {
        ZStack {
            Circle().fill(Theme.accent.opacity(0.04)).frame(width: 280).blur(radius: 60).offset(x: -70, y: -180)
            Circle().fill(Color.green.opacity(0.05)).frame(width: 220).blur(radius: 50).offset(x: 90, y: 250)
        }
        .ignoresSafeArea()
    }

    // MARK: - Feature Chip
    private func featureChip(icon: String, text: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon).font(.system(size: 9, weight: .semibold))
            Text(text).font(.system(size: 11, weight: .semibold))
        }
        .foregroundStyle(.white.opacity(0.5))
        .padding(.horizontal, 11)
        .padding(.vertical, 6)
        .background(.white.opacity(0.06))
        .clipShape(Capsule())
        .overlay(Capsule().stroke(.white.opacity(0.06), lineWidth: 1))
    }

    // MARK: - Animations
    private func startAnimations() {
        withAnimation(.spring(response: 0.7, dampingFraction: 0.7)) {
            showBranding = true
            flagScale = 1.0
        }
        withAnimation(.easeOut(duration: 0.5).delay(0.35)) { showForm = true }
        withAnimation(.easeOut(duration: 0.5).delay(0.55)) { showButton = true }
    }

    // MARK: - Goal Selection (Foundation Session A)
    /// The five goal options shown on the goal step. nil represents
    /// "I don't have one yet" — stored as nil on Golfer.scoringGoal.
    private static let goalOptions: [(label: String, subtitle: String, value: Int?)] = [
        ("Break 100", "First milestone for new players", 100),
        ("Break 90",  "The bogey golfer breakthrough", 90),
        ("Break 80",  "Single-digit handicap territory", 80),
        ("Break 70",  "Scratch-or-better company", 70),
        ("I don't have one yet", "Pick later from settings", nil),
    ]

    private var goalSelectionCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("What's your goal?")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text("We'll track your progress.")
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.55))
            }
            .padding(.horizontal, 4)

            VStack(spacing: 10) {
                ForEach(0..<Self.goalOptions.count, id: \.self) { i in
                    let option = Self.goalOptions[i]
                    Button {
                        completeOnboarding(goal: option.value)
                    } label: {
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(option.label)
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(.white)
                                Text(option.subtitle)
                                    .font(.system(size: 12))
                                    .foregroundStyle(.white.opacity(0.5))
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(.white.opacity(0.4))
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .background(.white.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(.white.opacity(0.10), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(option.label)
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial.opacity(0.5))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(.white.opacity(0.03))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(.white.opacity(0.10), lineWidth: 1)
                )
        )
    }

    // MARK: - Complete
    private func completeOnboarding(goal: Int?) {
        Haptics.success()
        let golfer = Golfer(
            name: name.trimmingCharacters(in: .whitespaces),
            handicapIndex: Double(handicap) ?? 0,
            scoringGoal: goal
        )
        modelContext.insert(golfer)
        let bag = Bag.createFromTemplate(selectedTemplate)
        modelContext.insert(bag)
        golfer.defaultBagID = bag.id
        showWalkthrough = true
    }

    // MARK: - Bag Sheet
    struct OnboardingBagSheet: View {
        @Environment(\.dismiss) private var dismiss
        @Binding var selectedTemplate: BagTemplate

        var body: some View {
            NavigationStack {
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(BagTemplate.allCases) { template in
                            BagTemplateCard(
                                template: template,
                                isSelected: selectedTemplate == template,
                                onTap: {
                                    selectedTemplate = template
                                    Haptics.selection()
                                    dismiss()
                                }
                            )
                        }
                    }
                    .padding()
                }
                .navigationTitle("Choose Bag")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                    }
                }
            }
            .presentationDetents([.medium, .large])
        }
    }
}

// MARK: - Welcome Walkthrough (post-signup)
struct WelcomeWalkthroughView: View {
    var onComplete: () -> Void
    @State private var currentPage = 0

    private let pages: [(icon: String, title: String, subtitle: String, color: Color)] = [
        ("flag.fill", "Start a Round", "Pick from 660+ courses or add your own.\nQuick-score any hole in one tap.", Color(red: 0.13, green: 0.37, blue: 0.25)),
        ("chart.bar.fill", "Track Your Stats", "Score trends, strokes gained, handicap projection.\nWatch your game improve over time.", Color(red: 0.2, green: 0.5, blue: 0.7)),
        ("trophy.fill", "Set Goals & Earn Achievements", "Break 80, lower your handicap, build streaks.\n17 milestones waiting to be unlocked.", Color(red: 0.75, green: 0.55, blue: 0.2)),
    ]

    var body: some View {
        ZStack {
            // Background
            pages[currentPage].color
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 0.4), value: currentPage)

            VStack(spacing: 0) {
                Spacer()

                // Icon
                Image(systemName: pages[currentPage].icon)
                    .font(.system(size: 64))
                    .foregroundStyle(.white)
                    .shadow(color: .white.opacity(0.2), radius: 16, y: 4)
                    .id(currentPage) // force re-render for transition
                    .transition(.scale.combined(with: .opacity))

                Spacer().frame(height: 32)

                // Text
                VStack(spacing: 10) {
                    Text(pages[currentPage].title)
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    Text(pages[currentPage].subtitle)
                        .font(.system(size: 15))
                        .foregroundStyle(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }
                .padding(.horizontal, 32)
                .id(currentPage)
                .transition(.opacity)

                Spacer()

                // Page dots
                HStack(spacing: 8) {
                    ForEach(0..<pages.count, id: \.self) { i in
                        Circle()
                            .fill(i == currentPage ? .white : .white.opacity(0.3))
                            .frame(width: 8, height: 8)
                            .scaleEffect(i == currentPage ? 1.2 : 1.0)
                            .animation(.spring(response: 0.3), value: currentPage)
                    }
                }

                Spacer().frame(height: 32)

                // Button
                Button {
                    if currentPage < pages.count - 1 {
                        withAnimation(.easeInOut(duration: 0.35)) {
                            currentPage += 1
                        }
                    } else {
                        onComplete()
                    }
                } label: {
                    Text(currentPage < pages.count - 1 ? "Next" : "Let's Go!")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(pages[currentPage].color)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 17)
                        .background(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
                }
                .padding(.horizontal, 28)

                // Skip
                if currentPage < pages.count - 1 {
                    Button("Skip") {
                        onComplete()
                    }
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.5))
                    .padding(.top, 12)
                }

                Spacer().frame(height: 40)
            }
        }
    }
}
