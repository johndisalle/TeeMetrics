// MARK: - Settings View
// Profile, subscription, data, sample data, rate, legal, about

import SwiftUI
import SwiftData
import StoreKit

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.requestReview) private var requestReview
    @Query private var golfers: [Golfer]
    @Query(sort: \GolfRound.date, order: .reverse) private var rounds: [GolfRound]
    @AppStorage("iCloudSyncEnabled") private var iCloudSync = false
    @AppStorage("selectedTheme") private var selectedTheme = "green"
    @State private var showExportSheet = false
    @State private var showDeleteAlert = false
    @State private var showSampleDataLoaded = false
    @State private var exportData = ""

    private var golfer: Golfer? { golfers.first }
    private var completedRoundsCount: Int { rounds.filter { $0.isCompleted }.count }

    // MARK: - GitHub Pages URLs
    private let termsURL = URL(string: "https://johndisalle.github.io/TeeMetrics/terms")!
    private let privacyURL = URL(string: "https://johndisalle.github.io/TeeMetrics/privacy")!
    private let supportURL = URL(string: "https://johndisalle.github.io/TeeMetrics/support")!

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
                                Text("$29.99/yr")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                // MARK: - Data
                Section("Data") {
                    Toggle(isOn: $iCloudSync) {
                        Label("iCloud Sync", systemImage: "icloud")
                    }

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

                    Button {
                        SampleDataSeeder.loadSampleData(into: modelContext)
                        showSampleDataLoaded = true
                        Haptics.success()
                    } label: {
                        Label("Load Sample Data", systemImage: "tray.and.arrow.down.fill")
                    }
                }

                // MARK: - Appearance
                Section("Appearance") {
                    Picker(selection: $selectedTheme) {
                        Text("Golf Green").tag("green")
                        Text("Classic").tag("classic")
                    } label: {
                        Label("Theme", systemImage: "paintbrush")
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

                    Link(destination: supportURL) {
                        Label("Customer Support", systemImage: "questionmark.circle")
                    }
                }

                // MARK: - Legal
                Section("Legal") {
                    Link(destination: termsURL) {
                        Label("Terms of Service", systemImage: "doc.text")
                    }
                    Link(destination: privacyURL) {
                        Label("Privacy Policy", systemImage: "lock.shield")
                    }
                }

                // MARK: - About
                Section("About") {
                    HStack {
                        Label("Version", systemImage: "info.circle")
                        Spacer()
                        Text("1.0.0")
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
            .alert("Sample Data Loaded", isPresented: $showSampleDataLoaded) {
                Button("OK") { }
            } message: {
                Text("2 courses and 5 demo rounds have been added. Check your Dashboard and Stats!")
            }
            .sheet(isPresented: $showExportSheet) {
                ShareLink(item: exportData)
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
