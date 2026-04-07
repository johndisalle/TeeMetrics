// MARK: - Settings View
// Pro subscription, iCloud sync toggle, data export, theme, about

import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var golfers: [Golfer]
    @Query(sort: \GolfRound.date, order: .reverse) private var rounds: [GolfRound]
    @AppStorage("iCloudSyncEnabled") private var iCloudSync = false
    @AppStorage("selectedTheme") private var selectedTheme = "green"
    @State private var showExportSheet = false
    @State private var showDeleteAlert = false
    @State private var exportData = ""

    private var golfer: Golfer? { golfers.first }

    var body: some View {
        NavigationStack {
            List {
                // MARK: - Profile
                Section("Profile") {
                    if let golfer {
                        HStack {
                            Image(systemName: golfer.avatarSystemName)
                                .font(.title)
                                .foregroundStyle(Theme.primary)
                                .frame(width: 50, height: 50)
                                .background(Theme.primary.opacity(0.1))
                                .clipShape(Circle())
                            VStack(alignment: .leading) {
                                Text(golfer.name)
                                    .font(.headline)
                                Text("Handicap: \(String(format: "%.1f", golfer.handicapIndex))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        NavigationLink("Edit Profile") {
                            EditProfileView(golfer: golfer)
                        }
                    }
                }

                // MARK: - Pro
                Section("Subscription") {
                    NavigationLink {
                        SubscriptionView()
                    } label: {
                        HStack {
                            Image(systemName: SubscriptionManager.shared.isProUser ? "crown.fill" : "crown")
                                .foregroundStyle(Theme.accent)
                            Text(SubscriptionManager.shared.isProUser ? "Pro Active" : "Upgrade to Pro")
                        }
                    }
                }

                // MARK: - Data
                Section("Data") {
                    Toggle("iCloud Sync", isOn: $iCloudSync)

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

                // MARK: - Theme
                Section("Appearance") {
                    Picker("Theme", selection: $selectedTheme) {
                        Text("Golf Green").tag("green")
                        Text("Classic").tag("classic")
                    }
                }

                // MARK: - About
                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("Rounds Logged")
                        Spacer()
                        Text("\(rounds.filter { $0.isCompleted }.count)")
                            .foregroundStyle(.secondary)
                    }
                }

                // MARK: - Danger Zone
                Section {
                    Button("Delete All Data", role: .destructive) {
                        showDeleteAlert = true
                    }
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
        }
    }

    private func exportCSV() {
        var csv = "Date,Course,Score,Putts,Fairway%,GIR%\n"
        for round in rounds.filter({ $0.isCompleted }) {
            csv += "\(round.date.shortFormatted),\(round.course?.name ?? ""),\(round.totalScore),\(round.totalPutts),\(String(format: "%.0f", round.fairwayPercentage)),\(String(format: "%.0f", round.girPercentage))\n"
        }
        exportData = csv
        showExportSheet = true
    }

    private func deleteAllData() {
        try? modelContext.delete(model: GolfRound.self)
        try? modelContext.delete(model: GolfCourse.self)
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
            TextField("Name", text: $golfer.name)
            TextField("Handicap Index", text: $handicapText)
                .keyboardType(.decimalPad)
                .onAppear { handicapText = String(format: "%.1f", golfer.handicapIndex) }
                .onChange(of: handicapText) { _, newVal in
                    golfer.handicapIndex = Double(newVal) ?? golfer.handicapIndex
                }
        }
        .navigationTitle("Edit Profile")
    }
}
