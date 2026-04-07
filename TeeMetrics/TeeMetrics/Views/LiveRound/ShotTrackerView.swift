// MARK: - Shot Tracker View
// Shot-by-shot club selection, distance, lie type, result tracking

import SwiftUI
import SwiftData

struct ShotTrackerView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Bindable var holeEntry: HoleEntry
    @Query(filter: #Predicate<Bag> { $0.isDefault == true }) private var bags: [Bag]

    @State private var selectedClub = ""
    @State private var distance = ""
    @State private var selectedLie: LieType = .tee
    @State private var selectedResult: ShotResult = .hit

    private var clubs: [Club] {
        bags.first?.sortedClubs ?? []
    }

    private var sortedShots: [ShotEntry] {
        holeEntry.shots.sorted { $0.shotNumber < $1.shotNumber }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                // MARK: - Shot List
                if !sortedShots.isEmpty {
                    List {
                        ForEach(sortedShots) { shot in
                            HStack {
                                Text("#\(shot.shotNumber)")
                                    .font(.caption.bold())
                                    .frame(width: 30)
                                Text(shot.clubUsed)
                                    .font(.subheadline.bold())
                                Spacer()
                                if shot.distanceYards > 0 {
                                    Text("\(shot.distanceYards) yds")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Text(shot.lieType.capitalized)
                                    .font(.caption)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.gray.opacity(0.15))
                                    .clipShape(Capsule())
                            }
                        }
                        .onDelete(perform: deleteShots)
                    }
                    .listStyle(.plain)
                    .frame(maxHeight: 200)
                }

                Divider()

                // MARK: - Club Selector (horizontal scroll)
                VStack(alignment: .leading, spacing: 8) {
                    Text("CLUB")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(clubs) { club in
                                Button {
                                    selectedClub = club.name
                                    Haptics.selection()
                                } label: {
                                    VStack(spacing: 4) {
                                        Image(systemName: club.systemImage)
                                            .font(.title3)
                                        Text(club.name)
                                            .font(.caption2.bold())
                                        if club.avgDistance > 0 {
                                            Text("\(club.avgDistance)y")
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    .frame(width: 60, height: 70)
                                    .background(selectedClub == club.name ? Theme.primary : Color.gray.opacity(0.1))
                                    .foregroundStyle(selectedClub == club.name ? .white : .primary)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                }
                                .accessibilityLabel("\(club.name)\(club.avgDistance > 0 ? ", \(club.avgDistance) yards" : "")")
                                .accessibilityAddTraits(selectedClub == club.name ? .isSelected : [])
                            }
                        }
                    }
                }
                .padding(.horizontal)

                // MARK: - Distance + Lie + Result
                HStack {
                    VStack(alignment: .leading) {
                        Text("DISTANCE")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                        TextField("Yds", text: $distance)
                            .keyboardType(.numberPad)
                            .textFieldStyle(.roundedBorder)
                    }

                    VStack(alignment: .leading) {
                        Text("LIE")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                        Picker("Lie", selection: $selectedLie) {
                            ForEach(LieType.allCases) { lie in
                                Text(lie.displayName).tag(lie)
                            }
                        }
                        .pickerStyle(.menu)
                    }

                    VStack(alignment: .leading) {
                        Text("RESULT")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                        Picker("Result", selection: $selectedResult) {
                            ForEach(ShotResult.allCases) { r in
                                Text(r.displayName).tag(r)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                }
                .padding(.horizontal)

                // MARK: - Add Shot Button
                Button {
                    addShot()
                } label: {
                    Label("Log Shot", systemImage: "plus.circle.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Theme.primary)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal)
                .disabled(selectedClub.isEmpty)

                Spacer()
            }
            .navigationTitle("Shot Tracker - Hole \(holeEntry.holeNumber)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func addShot() {
        let shotNum = sortedShots.count + 1
        let shot = ShotEntry(
            shotNumber: shotNum,
            clubUsed: selectedClub,
            distanceYards: Int(distance) ?? 0,
            lieType: selectedLie.rawValue,
            result: selectedResult.rawValue,
            holeEntry: holeEntry
        )
        modelContext.insert(shot)
        holeEntry.shots.append(shot)

        // Update club stats
        if let club = clubs.first(where: { $0.name == selectedClub }),
           let dist = Int(distance), dist > 0 {
            club.updateDistance(newDistance: dist)
        }

        Haptics.medium()
        distance = ""
        selectedLie = .fairway
    }

    private func deleteShots(at offsets: IndexSet) {
        for index in offsets {
            let shot = sortedShots[index]
            modelContext.delete(shot)
        }
    }
}
