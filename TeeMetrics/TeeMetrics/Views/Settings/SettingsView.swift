// MARK: - Settings View
// Profile, subscription, data, appearance (light/dark/system), legal, about

import SwiftUI
import SwiftData
import StoreKit

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.requestReview) private var requestReview
    @Query private var golfers: [Golfer]
    @Query(sort: \GolfRound.date, order: .reverse) private var rounds: [GolfRound]
    @AppStorage("selectedAppearance") private var selectedAppearance = "system"
    @State private var showExportSheet = false
    @State private var showDeleteAlert = false
    @State private var showRedeemCode = false
    @State private var exportData = ""

    private var golfer: Golfer? { golfers.first }
    private var completedRoundsCount: Int { rounds.filter { $0.isCompleted }.count }

    var body: some View {
        NavigationStack {
            List {
                // MARK: - Profile
                Section {
                    if let golfer {
                        HStack(spacing: 14) {
                            Image(systemName: golfer.avatarSystemName)
                                .font(.title2)
                                .foregroundStyle(.white)
                                .frame(width: 48, height: 48)
                                .background(Theme.golfGradient)
                                .clipShape(Circle())
                            VStack(alignment: .leading, spacing: 2) {
                                Text(golfer.name)
                                    .font(.headline)
                                Text("Handicap: \(String(format: "%.1f", golfer.handicapIndex))")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                        }

                        NavigationLink {
                            EditProfileView(golfer: golfer)
                        } label: {
                            Label("Edit Profile", systemImage: "pencil")
                        }
                    }
                } header: {
                    Text("Profile")
                }

                // MARK: - Subscription
                Section("Subscription") {
                    NavigationLink {
                        SubscriptionView()
                    } label: {
                        HStack {
                            Image(systemName: SubscriptionManager.shared.isProUser ? "crown.fill" : "crown")
                                .foregroundStyle(Theme.accent)
                            Text(SubscriptionManager.shared.isProUser ? "Pro Active" : "Upgrade to Pro")
                            Spacer()
                            if !SubscriptionManager.shared.isProUser {
                                Text("3-day free trial")
                                    .font(.caption)
                                    .foregroundStyle(Theme.primary)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(Theme.primary.opacity(0.1))
                                    .clipShape(Capsule())
                            }
                        }
                    }

                    if !SubscriptionManager.shared.isProUser {
                        Button {
                            showRedeemCode = true
                        } label: {
                            Label("Redeem Offer Code", systemImage: "ticket.fill")
                        }
                    }
                }

                // MARK: - Data
                Section("Data") {
                    Button {
                        exportCSV()
                    } label: {
                        Label("Export CSV", systemImage: "square.and.arrow.up")
                    }

                    NavigationLink {
                        CourseLibraryView()
                    } label: {
                        Label("Course Library", systemImage: "flag.fill")
                    }

                }

                // MARK: - Appearance
                Section("Appearance") {
                    Picker(selection: $selectedAppearance) {
                        Label("System", systemImage: "circle.lefthalf.filled")
                            .tag("system")
                        Label("Light", systemImage: "sun.max.fill")
                            .tag("light")
                        Label("Dark", systemImage: "moon.fill")
                            .tag("dark")
                    } label: {
                        Label("Appearance", systemImage: "paintbrush")
                    }
                }

                // MARK: - Notifications
                Section("Notifications") {
                    Button {
                        NotificationManager.requestPermission()
                        Haptics.light()
                    } label: {
                        Label("Enable Notifications", systemImage: "bell.badge")
                    }
                }

                // MARK: - Support & Feedback
                Section("Support") {
                    Button {
                        requestReview()
                    } label: {
                        Label("Rate TeeMetrics", systemImage: "star.fill")
                            .foregroundStyle(Theme.accent)
                    }

                    Link(destination: AppURLs.support) {
                        Label("Customer Support", systemImage: "questionmark.circle")
                    }
                }

                // MARK: - Legal
                Section("Legal") {
                    Link(destination: AppURLs.terms) {
                        Label("Terms of Service", systemImage: "doc.text")
                    }
                    Link(destination: AppURLs.privacy) {
                        Label("Privacy Policy", systemImage: "lock.shield")
                    }
                }

                // MARK: - About
                Section("About") {
                    HStack {
                        Label("Version", systemImage: "info.circle")
                        Spacer()
                        Text(AppConfig.appVersion)
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Label("Rounds Logged", systemImage: "flag.checkered")
                        Spacer()
                        Text("\(completedRoundsCount)")
                            .foregroundStyle(.secondary)
                    }
                }

                // MARK: - Danger Zone
                Section {
                    Button(role: .destructive) {
                        showDeleteAlert = true
                    } label: {
                        Label("Delete All Data", systemImage: "trash")
                    }
                } footer: {
                    Text("All data is stored privately on your device.")
                        .font(.caption)
                }
            }
            .navigationTitle("Settings")
            .alert("Delete All Data?", isPresented: $showDeleteAlert) {
                Button("Delete", role: .destructive) { deleteAllData() }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This cannot be undone. All rounds, courses, and clubs will be permanently deleted.")
            }
            .sheet(isPresented: $showExportSheet) {
                ShareLink(item: exportData)
            }
            .offerCodeRedemption(isPresented: $showRedeemCode) { result in
                switch result {
                case .success:
                    Task { await SubscriptionManager.shared.updatePurchasedProducts() }
                case .failure:
                    break
                @unknown default:
                    break
                }
            }
        }
    }

    // MARK: - Export CSV
    private func exportCSV() {
        var csv = "Date,Course,Score,Putts,Fairway%,GIR%\n"
        for round in rounds.filter({ $0.isCompleted }) {
            csv += "\(round.date.shortFormatted),\(round.course?.name ?? ""),\(round.totalScore),\(round.totalPutts),\(String(format: "%.0f", round.fairwayPercentage)),\(String(format: "%.0f", round.girPercentage))\n"
        }
        exportData = csv
        showExportSheet = true
    }

    // MARK: - Delete All
    private func deleteAllData() {
        SampleDataSeeder.clearAllData(context: modelContext)
        try? modelContext.delete(model: Bag.self)
        try? modelContext.delete(model: Golfer.self)
    }
}

// MARK: - Edit Profile
struct EditProfileView: View {
    @Bindable var golfer: Golfer
    @State private var handicapText: String = ""

    var body: some View {
        Form {
            Section("Personal") {
                TextField("Name", text: $golfer.name)
                TextField("Handicap Index", text: $handicapText)
                    .keyboardType(.decimalPad)
                    .onAppear { handicapText = String(format: "%.1f", golfer.handicapIndex) }
                    .onChange(of: handicapText) { _, newVal in
                        golfer.handicapIndex = Double(newVal) ?? golfer.handicapIndex
                    }
            }
        }
        .navigationTitle("Edit Profile")
    }
}
