// MARK: - Watch Round View
// Simplified per-hole scoring for Apple Watch
// Quick score entry, putts, running total

import SwiftUI

struct WatchRoundView: View {
    @State private var currentHole = 1
    @State private var scores: [Int] = Array(repeating: 0, count: 18)
    @State private var putts: [Int] = Array(repeating: 0, count: 18)
    @State private var pars: [Int] = [4, 5, 3, 4, 4, 3, 4, 5, 4, 4, 5, 3, 4, 4, 3, 4, 5, 4] // default par 72

    private var currentIndex: Int { currentHole - 1 }
    private var runningScore: Int { scores.prefix(currentHole).reduce(0, +) }
    private var runningPar: Int { pars.prefix(currentHole).reduce(0, +) }
    private var toPar: Int { runningScore - runningPar }

    var body: some View {
        TabView(selection: $currentHole) {
            ForEach(1...18, id: \.self) { hole in
                watchHoleView(hole: hole)
                    .tag(hole)
            }
        }
        .tabViewStyle(.verticalPage)
        .navigationTitle("Hole \(currentHole)")
    }

    private func watchHoleView(hole: Int) -> some View {
        let idx = hole - 1
        return VStack(spacing: 6) {
            // Hole header
            HStack {
                Text("H\(hole)")
                    .font(.headline)
                Spacer()
                Text("P\(pars[idx])")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Score
            HStack {
                Button {
                    if scores[idx] > 0 { scores[idx] -= 1 }
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.title3)
                }
                .buttonStyle(.plain)

                Text("\(scores[idx])")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .frame(width: 50)

                Button {
                    scores[idx] += 1
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                }
                .buttonStyle(.plain)
            }

            // Putts
            HStack {
                Text("Putts")
                    .font(.caption2)
                Spacer()
                Button { if putts[idx] > 0 { putts[idx] -= 1 } } label: {
                    Image(systemName: "minus.circle")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                Text("\(putts[idx])")
                    .font(.caption.bold())
                Button { putts[idx] += 1 } label: {
                    Image(systemName: "plus.circle")
                        .font(.caption)
                }
                .buttonStyle(.plain)
            }

            // Running total
            Divider()
            HStack {
                Text("Total: \(runningScore)")
                    .font(.caption2)
                Spacer()
                Text(toPar == 0 ? "E" : (toPar > 0 ? "+\(toPar)" : "\(toPar)"))
                    .font(.caption2.bold())
                    .foregroundStyle(toPar <= 0 ? .green : .red)
            }
        }
        .padding(.horizontal, 4)
    }
}
