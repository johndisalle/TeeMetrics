// MARK: - Bag Template Picker
// Beautiful template selection for onboarding and bag manager reset

import SwiftUI
import SwiftData

struct BagTemplatePicker: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    var onBagCreated: ((Bag) -> Void)?

    @State private var selectedTemplate: BagTemplate = .standard
    @State private var showPreview = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Header
                    VStack(spacing: 6) {
                        Text("Choose Your Bag")
                            .font(.title2.bold())
                        Text("Pick a setup that matches your game.\nYou can customize it anytime.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 8)

                    // Template Cards
                    ForEach(BagTemplate.allCases) { template in
                        BagTemplateCard(
                            template: template,
                            isSelected: selectedTemplate == template,
                            onTap: {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    selectedTemplate = template
                                }
                                Haptics.selection()
                            }
                        )
                    }

                    // Preview
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("What's in this bag")
                                .font(.subheadline.bold())
                            Spacer()
                            Text("\(selectedTemplate.clubCount) clubs")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        ForEach(Array(selectedTemplate.clubs.enumerated()), id: \.offset) { i, club in
                            HStack(spacing: 12) {
                                Image(systemName: clubIcon(club.1))
                                    .font(.caption)
                                    .foregroundStyle(Theme.primary)
                                    .frame(width: 20)
                                Text(club.0)
                                    .font(.subheadline)
                                Spacer()
                                if club.2 > 0 {
                                    Text("\(club.2) yds")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.vertical, 2)
                            if i < selectedTemplate.clubs.count - 1 {
                                Divider()
                            }
                        }
                    }
                    .padding()
                    .background(Theme.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 14))

                    // Confirm button
                    Button {
                        createBag()
                    } label: {
                        Text("Use This Bag")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Theme.primary)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                }
                .padding()
            }
            .navigationTitle("Bag Setup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func clubIcon(_ type: String) -> String {
        switch type {
        case "driver": return "figure.golf"
        case "wood": return "leaf.fill"
        case "hybrid": return "leaf.arrow.triangle.circlepath"
        case "iron": return "line.diagonal"
        case "wedge": return "triangle.fill"
        case "putter": return "hockey.puck.fill"
        default: return "sportscourt.fill"
        }
    }

    private func createBag() {
        // Delete existing default bag
        let descriptor = FetchDescriptor<Bag>(predicate: #Predicate { $0.isDefault == true })
        if let existing = try? modelContext.fetch(descriptor) {
            for bag in existing {
                modelContext.delete(bag)
            }
        }

        let bag = Bag.createFromTemplate(selectedTemplate)
        modelContext.insert(bag)
        onBagCreated?(bag)
        Haptics.success()
        dismiss()
    }
}

// MARK: - Template Card
struct BagTemplateCard: View {
    let template: BagTemplate
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                Image(systemName: template.icon)
                    .font(.title2)
                    .foregroundStyle(isSelected ? .white : Theme.primary)
                    .frame(width: 44, height: 44)
                    .background(isSelected ? Theme.primary : Theme.primary.opacity(0.1))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 3) {
                    Text(template.rawValue)
                        .font(.subheadline.bold())
                        .foregroundStyle(.primary)
                    Text(template.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(Theme.primary)
                }
            }
            .padding(14)
            .background(isSelected ? Theme.primary.opacity(0.08) : Theme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isSelected ? Theme.primary : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}
