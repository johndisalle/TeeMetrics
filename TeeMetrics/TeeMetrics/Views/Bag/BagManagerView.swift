// MARK: - Bag Manager
// Add/edit clubs, view avg distances, historical tracking per club

import SwiftUI
import SwiftData

struct BagManagerView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<Bag> { $0.isDefault == true }) private var bags: [Bag]
    @State private var showAddClub = false
    @State private var showTemplatePicker = false

    private var bag: Bag? { bags.first }

    private var sortedClubs: [Club] {
        bag?.sortedClubs ?? []
    }

    var body: some View {
        NavigationStack {
            Group {
                if bags.first != nil {
                    List {
                        ForEach(clubsByType) { group in
                            Section(group.type.capitalized) {
                                ForEach(group.clubs) { club in
                                    NavigationLink {
                                        ClubDetailView(club: club)
                                    } label: {
                                        ClubRow(club: club)
                                    }
                                }
                                .onDelete { offsets in
                                    deleteClubs(in: group, at: offsets)
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                } else {
                    ContentUnavailableView(
                        "No Bag",
                        systemImage: "bag.fill",
                        description: Text("Create a bag to get started")
                    )
                }
            }
            .navigationTitle("My Bag")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button {
                            showAddClub = true
                        } label: {
                            Label("Add Club", systemImage: "plus.circle")
                        }
                        Button {
                            showTemplatePicker = true
                        } label: {
                            Label("Reset to Template", systemImage: "arrow.counterclockwise")
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showAddClub) {
                AddClubView(bag: bag)
            }
            .sheet(isPresented: $showTemplatePicker) {
                BagTemplatePicker()
            }
        }
    }

    private var clubsByType: [ClubGroup] {
        let types = ["driver", "wood", "hybrid", "iron", "wedge", "putter"]
        return types.compactMap { type in
            let clubs = sortedClubs.filter { $0.clubType == type }
            guard !clubs.isEmpty else { return nil }
            return ClubGroup(type: type, clubs: clubs)
        }
    }

    private func deleteClubs(in group: ClubGroup, at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(group.clubs[index])
        }
    }
}

struct ClubGroup: Identifiable {
    let type: String
    let clubs: [Club]
    var id: String { type }
}

// MARK: - Club Row
struct ClubRow: View {
    let club: Club

    var body: some View {
        HStack {
            Image(systemName: club.systemImage)
                .foregroundStyle(Theme.primary)
                .frame(width: 30)
            VStack(alignment: .leading, spacing: 2) {
                Text(club.name)
                    .font(.subheadline.bold())
                if club.totalShots > 0 {
                    Text("\(club.totalShots) shots tracked")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            if club.avgDistance > 0 {
                VStack(alignment: .trailing) {
                    Text("\(club.avgDistance) yds")
                        .font(.subheadline.bold())
                    if club.minDistance != club.maxDistance {
                        Text("\(club.minDistance)-\(club.maxDistance)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}

// MARK: - Club Detail View
struct ClubDetailView: View {
    @Bindable var club: Club

    var body: some View {
        Form {
            Section("Club Info") {
                TextField("Name", text: $club.name)
                Picker("Type", selection: $club.clubType) {
                    ForEach(ClubType.allCases) { type in
                        Text(type.displayName).tag(type.rawValue)
                    }
                }
            }

            Section("Distances") {
                HStack {
                    Text("Average")
                    Spacer()
                    TextField("Yds", value: $club.avgDistance, format: .number)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 80)
                }
                if club.totalShots > 0 {
                    HStack {
                        Text("Min")
                        Spacer()
                        Text("\(club.minDistance) yds")
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("Max")
                        Spacer()
                        Text("\(club.maxDistance) yds")
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section("Stats") {
                HStack {
                    Text("Total Shots")
                    Spacer()
                    Text("\(club.totalShots)")
                        .foregroundStyle(.secondary)
                }
                if let lastUsed = club.lastUsed {
                    HStack {
                        Text("Last Used")
                        Spacer()
                        Text(lastUsed.shortFormatted)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle(club.name)
    }
}

// MARK: - Add Club View
struct AddClubView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let bag: Bag?

    @State private var name = ""
    @State private var clubType = "iron"
    @State private var avgDistance = ""

    var body: some View {
        NavigationStack {
            Form {
                TextField("Club Name", text: $name)
                Picker("Type", selection: $clubType) {
                    ForEach(ClubType.allCases) { type in
                        Text(type.displayName).tag(type.rawValue)
                    }
                }
                TextField("Average Distance (yards)", text: $avgDistance)
                    .keyboardType(.numberPad)
            }
            .navigationTitle("Add Club")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { addClub() }
                        .disabled(name.isEmpty)
                }
            }
        }
    }

    private func addClub() {
        let club = Club(
            name: name,
            clubType: clubType,
            avgDistance: Int(avgDistance) ?? 0,
            sortOrder: (bag?.clubs.count ?? 0),
            bag: bag
        )
        modelContext.insert(club)
        Haptics.success()
        dismiss()
    }
}
