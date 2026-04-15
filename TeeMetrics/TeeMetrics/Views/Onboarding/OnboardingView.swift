// MARK: - Onboarding
// Three flat screens, no walkthrough, no glassmorphism, no gradients.
//
// Flow:
//   SplashScreen           — flag, name, tagline, "Get Started"
//   → ProfileFormScreen    — name / handicap / bag (native Form)
//     → GoalScreen         — 5 goal rows, single-tap select-and-finish
//       → MainTabView (via hasCompletedOnboarding flip)
//
// All chrome routes through the `Theme` semantic tokens added in the
// foundation pass. Nothing here uses `.ultraThinMaterial`, RadialGradient,
// drop-shadow glows, or hand-tuned hex values.

import SwiftUI
import SwiftData

struct OnboardingView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    /// Profile form state, hoisted so the goal step can read it on submit.
    @State private var name = ""
    @State private var handicap = ""
    @State private var selectedTemplate: BagTemplate = .standard

    var body: some View {
        NavigationStack {
            SplashScreen(
                profileDestination: ProfileFormScreen(
                    name: $name,
                    handicap: $handicap,
                    selectedTemplate: $selectedTemplate,
                    goalDestination: GoalScreen(onComplete: completeOnboarding)
                )
            )
        }
        .tint(Theme.primary)
    }

    // MARK: - Complete
    /// Called from `GoalScreen` once the user picks one of the five
    /// options. Inserts Golfer + Bag, then flips the AppStorage flag so
    /// the root scene swaps to MainTabView. No walkthrough between.
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

        withAnimation { hasCompletedOnboarding = true }
    }
}

// MARK: - Splash Screen
/// The first screen on a fresh install. Solid theme background, single
/// flag icon, name + tagline, one primary CTA, one legal link.
struct SplashScreen<Destination: View>: View {
    let profileDestination: Destination

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                // Top spacer takes 1 share, the spacer below the cluster
                // takes 2 shares — anchors the flag/title cluster at
                // roughly the upper third of the screen.
                Spacer(minLength: 0)

                // Flag — flat, no glow, no shadow, no halo.
                Image(systemName: "flag.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(Theme.accent)

                Spacer().frame(height: 24)

                Text("TeeMetrics")
                    .font(.largeTitle.bold())
                    .foregroundStyle(Theme.text)

                Spacer().frame(height: 8)

                Text("Golf stats. No account. No ads. No nonsense.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textMuted)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                Spacer().frame(height: 24)

                // Tertiary line — single muted reassurance row, no chips.
                Text("661 courses · Offline · Apple Watch")
                    .font(.caption2)
                    .foregroundColor(Theme.textMuted)
                    .multilineTextAlignment(.center)

                // Two flexible spacers below the cluster vs one above gives
                // the cluster a 1:2 vertical balance.
                Spacer(minLength: 0)
                Spacer(minLength: 0)

                // Primary CTA — solid, full width, clearly tappable.
                NavigationLink {
                    profileDestination
                } label: {
                    Text("Get Started")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Theme.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal, 24)

                Spacer().frame(height: 16)

                // Legal — single line, muted, low-noise.
                HStack(spacing: 6) {
                    Link("Terms", destination: AppURLs.terms)
                    Text("·").foregroundStyle(Theme.textMuted)
                    Link("Privacy", destination: AppURLs.privacy)
                }
                .font(.caption)
                .foregroundStyle(Theme.textMuted)

                Spacer().frame(height: 32)
            }
        }
        .navigationBarHidden(true)
    }
}

// MARK: - Profile Form Screen
/// Native iOS Form for name / handicap / bag. No glassmorphism, no
/// hand-rolled input rows — the system styling is what we want here.
struct ProfileFormScreen<Destination: View>: View {
    @Binding var name: String
    @Binding var handicap: String
    @Binding var selectedTemplate: BagTemplate
    let goalDestination: Destination

    @State private var showBagPicker = false

    private var canContinue: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                Form {
                    Section {
                        TextField("Name", text: $name)
                            .textContentType(.name)
                            .autocorrectionDisabled()
                        TextField("Handicap (optional)", text: $handicap)
                            .keyboardType(.decimalPad)
                    } header: {
                        Text("About You")
                    }

                    Section {
                        Button {
                            showBagPicker = true
                        } label: {
                            HStack {
                                Image(systemName: selectedTemplate.icon)
                                    .foregroundStyle(Theme.primary)
                                Text(selectedTemplate.rawValue)
                                    .foregroundStyle(Theme.text)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption.bold())
                                    .foregroundStyle(Theme.textMuted)
                            }
                        }
                    } header: {
                        Text("Bag Setup")
                    } footer: {
                        Text("You can change this any time from Settings.")
                    }
                }
                .scrollContentBackground(.hidden)
                .background(Theme.background)

                // Bottom CTA — pinned outside the Form so it always sits
                // above the keyboard and matches the splash button.
                NavigationLink {
                    goalDestination
                } label: {
                    Text("Continue")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(canContinue ? Theme.primary : Theme.primary.opacity(0.4))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .disabled(!canContinue)
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
            }
        }
        .navigationTitle("Your Profile")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showBagPicker) {
            OnboardingBagSheet(selectedTemplate: $selectedTemplate)
        }
    }
}

// MARK: - Goal Screen
/// Five tappable rows. Tap = save + finish onboarding. No CTA, no Next.
struct GoalScreen: View {
    let onComplete: (Int?) -> Void

    private static let goalOptions: [(label: String, subtitle: String, value: Int?)] = [
        ("Break 100", "First milestone for new players", 100),
        ("Break 90",  "The bogey golfer breakthrough", 90),
        ("Break 80",  "Single-digit handicap territory", 80),
        ("Break 70",  "Scratch-or-better company", 70),
        ("I don't have one yet", "Pick later from settings", nil),
    ]

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    Text("What's your goal?")
                        .font(.title2.bold())
                        .foregroundStyle(Theme.text)
                    Text("We'll track your progress.")
                        .font(.subheadline)
                        .foregroundStyle(Theme.textMuted)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .padding(.bottom, 20)

                VStack(spacing: 10) {
                    ForEach(0..<Self.goalOptions.count, id: \.self) { i in
                        let option = Self.goalOptions[i]
                        Button {
                            onComplete(option.value)
                        } label: {
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(option.label)
                                        .font(.body.weight(.semibold))
                                        .foregroundStyle(Theme.text)
                                    Text(option.subtitle)
                                        .font(.caption)
                                        .foregroundStyle(Theme.textMuted)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption.bold())
                                    .foregroundStyle(Theme.textMuted)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                            .background(Theme.surface)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(option.label)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
        }
        .navigationTitle("Goal")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Bag Sheet (kept from the prior onboarding)
/// Bottom sheet that lists every BagTemplate via the existing
/// BagTemplateCard. Single-tap select-and-dismiss.
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
