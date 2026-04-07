// MARK: - Practice / Range Mode
// Quick session tracking without a full round

import SwiftUI
import SwiftData

struct PracticeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \PracticeSession.date, order: .reverse) private var sessions: [PracticeSession]
    @State private var showNewSession = false

    var body: some View {
        NavigationStack {
            Group {
                if sessions.isEmpty {
                    ContentUnavailableView(
                        "No Practice Sessions",
                        systemImage: "figure.golf",
                        description: Text("Track your range and practice sessions")
                    )
                } else {
                    List {
                        ForEach(sessions) { session in
                            NavigationLink {
                                PracticeDetailView(session: session)
                            } label: {
                                PracticeRow(session: session)
                            }
                        }
                        .onDelete { offsets in
                            for i in offsets { modelContext.delete(sessions[i]) }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Practice")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { showNewSession = true } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showNewSession) {
                NewPracticeSessionView()
            }
        }
    }
}

struct PracticeRow: View {
    let session: PracticeSession

    var body: some View {
        HStack {
            Image(systemName: sessionIcon(session.sessionType))
                .foregroundStyle(Theme.primary)
                .frame(width: 36, height: 36)
                .background(Theme.primary.opacity(0.1))
                .clipShape(Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(session.sessionType.capitalized)
                    .font(.subheadline.bold())
                Text("\(session.date.shortFormatted) \u{2022} \(session.shotCount) shots")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if session.durationMinutes > 0 {
                Text("\(session.durationMinutes) min")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func sessionIcon(_ type: String) -> String {
        switch type {
        case "range": return "figure.golf"
        case "putting": return "circle.fill"
        case "chipping": return "triangle.fill"
        default: return "sportscourt.fill"
        }
    }
}

// MARK: - New Practice Session
struct NewPracticeSessionView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(filter: #Predicate<Bag> { $0.isDefault == true }) private var bags: [Bag]

    @State private var sessionType = "range"
    @State private var selectedClub = ""
    @State private var distance = ""
    @State private var shots: [(String, Int)] = [] // (club, distance)
    @State private var notes = ""

    private var clubs: [Club] { bags.first?.sortedClubs ?? [] }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                // Type picker
                Picker("Type", selection: $sessionType) {
                    Text("Range").tag("range")
                    Text("Putting").tag("putting")
                    Text("Chipping").tag("chipping")
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                // Club selector
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(clubs) { club in
                            Button {
                                selectedClub = club.name
                                Haptics.selection()
                            } label: {
                                Text(club.name)
                                    .font(.caption.bold())
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(selectedClub == club.name ? Theme.primary : Color.gray.opacity(0.1))
                                    .foregroundStyle(selectedClub == club.name ? .white : .primary)
                                    .clipShape(Capsule())
                            }
                        }
                    }
                    .padding(.horizontal)
                }

                // Distance + log
                HStack {
                    TextField("Distance (yds)", text: $distance)
                        .keyboardType(.numberPad)
                        .textFieldStyle(.roundedBorder)
                    Button {
                        logShot()
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundStyle(Theme.primary)
                    }
                    .disabled(selectedClub.isEmpty)
                }
                .padding(.horizontal)

                // Shot log
                List {
                    ForEach(Array(shots.enumerated()), id: \.offset) { i, shot in
                        HStack {
                            Text("#\(i + 1)")
                                .font(.caption.bold())
                                .frame(width: 30)
                            Text(shot.0)
                                .font(.subheadline)
                            Spacer()
                            if shot.1 > 0 {
                                Text("\(shot.1) yds")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .listStyle(.plain)

                // Notes
                TextField("Session notes...", text: $notes)
                    .textFieldStyle(.roundedBorder)
                    .padding(.horizontal)
            }
            .navigationTitle("Practice Session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveSession() }
                        .disabled(shots.isEmpty)
                }
            }
        }
    }

    private func logShot() {
        shots.append((selectedClub, Int(distance) ?? 0))
        // Update club stats
        if let club = clubs.first(where: { $0.name == selectedClub }),
           let dist = Int(distance), dist > 0 {
            club.updateDistance(newDistance: dist)
        }
        distance = ""
        Haptics.light()
    }

    private func saveSession() {
        let session = PracticeSession(sessionType: sessionType, notes: notes)
        modelContext.insert(session)

        for (club, dist) in shots {
            let shot = PracticeShot(clubUsed: club, distanceYards: dist, session: session)
            modelContext.insert(shot)
        }

        session.clubsUsed = Set(shots.map(\.0)).joined(separator: ", ")
        Haptics.success()
        dismiss()
    }
}

// MARK: - Practice Detail
struct PracticeDetailView: View {
    let session: PracticeSession

    var body: some View {
        List {
            Section("Session Info") {
                HStack { Text("Type"); Spacer(); Text(session.sessionType.capitalized).foregroundStyle(.secondary) }
                HStack { Text("Date"); Spacer(); Text(session.date.shortFormatted).foregroundStyle(.secondary) }
                HStack { Text("Shots"); Spacer(); Text("\(session.shotCount)").foregroundStyle(.secondary) }
                if !session.notes.isEmpty {
                    Text(session.notes).foregroundStyle(.secondary)
                }
            }

            Section("Shots") {
                ForEach(session.shots.sorted { $0.clubUsed < $1.clubUsed }) { shot in
                    HStack {
                        Text(shot.clubUsed).font(.subheadline.bold())
                        Spacer()
                        if shot.distanceYards > 0 {
                            Text("\(shot.distanceYards) yds").foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle("Practice Details")
    }
}
