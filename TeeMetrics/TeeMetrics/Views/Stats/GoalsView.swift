// MARK: - Goals View
// Set and track golf goals with progress bars

import SwiftUI
import SwiftData

struct GoalsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Goal.deadline) private var goals: [Goal]
    @State private var showAddGoal = false

    private var activeGoals: [Goal] { goals.filter { !$0.isCompleted && !$0.isExpired } }
    private var completedGoals: [Goal] { goals.filter { $0.isCompleted } }

    var body: some View {
        List {
            if activeGoals.isEmpty && completedGoals.isEmpty {
                Section {
                    VStack(spacing: 12) {
                        Image(systemName: "target")
                            .font(.largeTitle)
                            .foregroundStyle(Theme.primary.opacity(0.4))
                        Text("Set Your First Goal")
                            .font(.headline)
                        Text("Track your progress towards breaking 80,\nlowering your handicap, or anything else.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                }
            }

            if !activeGoals.isEmpty {
                Section("Active Goals") {
                    ForEach(activeGoals) { goal in
                        GoalRow(goal: goal)
                    }
                    .onDelete { offsets in
                        for i in offsets { modelContext.delete(activeGoals[i]) }
                    }
                }
            }

            if !completedGoals.isEmpty {
                Section("Completed") {
                    ForEach(completedGoals) { goal in
                        GoalRow(goal: goal)
                    }
                }
            }
        }
        .navigationTitle("Goals")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showAddGoal = true } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showAddGoal) {
            AddGoalView()
        }
    }
}

struct GoalRow: View {
    let goal: Goal

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: goal.goalTypeIcon)
                    .foregroundStyle(goal.isCompleted ? .green : Theme.primary)
                Text(goal.title)
                    .font(.subheadline.bold())
                Spacer()
                if goal.isCompleted {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                } else {
                    Text("\(goal.daysRemaining)d left")
                        .font(.caption)
                        .foregroundStyle(goal.daysRemaining <= 7 ? .orange : .secondary)
                }
            }

            ProgressView(value: goal.progress)
                .tint(goal.isCompleted ? .green : Theme.primary)

            Text("\(goal.progressPercentage)% complete")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Add Goal View
struct AddGoalView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var goalType = "score"
    @State private var targetValue = ""
    @State private var deadline = Calendar.current.date(byAdding: .month, value: 1, to: Date()) ?? Date()

    private let goalTypes = [
        ("score", "Break a Score"),
        ("handicap", "Lower Handicap"),
        ("putts", "Avg Putts Target"),
        ("fairways", "Fairway % Target"),
        ("gir", "GIR % Target"),
        ("rounds", "Rounds to Play"),
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section("Goal") {
                    Picker("Type", selection: $goalType) {
                        ForEach(goalTypes, id: \.0) { type in
                            Text(type.1).tag(type.0)
                        }
                    }
                    TextField("Goal Name", text: $title)
                    TextField("Target Value", text: $targetValue)
                        .keyboardType(.decimalPad)
                    DatePicker("Deadline", selection: $deadline, displayedComponents: .date)
                }
            }
            .navigationTitle("New Goal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveGoal() }
                        .disabled(title.isEmpty || targetValue.isEmpty)
                }
            }
        }
    }

    private func saveGoal() {
        let goal = Goal(
            title: title,
            goalType: goalType,
            targetValue: Double(targetValue) ?? 0,
            deadline: deadline
        )
        modelContext.insert(goal)
        Haptics.success()
        dismiss()
    }
}
