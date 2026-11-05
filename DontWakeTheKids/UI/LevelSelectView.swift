import SwiftUI

/// The list of levels. A level opens once the one before it is cleared.
struct LevelSelectView: View {
    @ObservedObject var progress: ProgressStore
    let onBack: () -> Void
    let onPlay: (LevelDefinition) -> Void

    var body: some View {
        ZStack {
            Color.night.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 16) {
                header
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(Array(LevelDefinition.all.enumerated()), id: \.element.id) { index, level in
                            LevelCard(number: index + 1,
                                      level: level,
                                      progress: progress.progress(for: level.id),
                                      unlocked: progress.isUnlocked(level.id)) {
                                onPlay(level)
                            }
                        }
                    }
                    .padding(.bottom, 24)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
        }
        .preferredColorScheme(.dark)
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 4) {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.body.weight(.heavy))
                    .foregroundStyle(Color.muted)
                    .frame(width: 32, height: 44)
            }
            .accessibilityLabel("Back")
            Text("Levels")
                .font(Fonts.hand(30, bold: true))
                .foregroundStyle(Color.ink)
            Spacer()
        }
    }
}

private struct LevelCard: View {
    let number: Int
    let level: LevelDefinition
    let progress: LevelProgress
    let unlocked: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Text("\(number)")
                    .font(.system(.title2, design: .rounded).weight(.heavy))
                    .foregroundStyle(unlocked ? Color.amber : Color.muted)
                    .frame(width: 36)
                VStack(alignment: .leading, spacing: 4) {
                    Text(level.title)
                        .font(Fonts.hand(20, bold: true))
                        .foregroundStyle(Color.ink)
                    Text(level.subtitle)
                        .font(.footnote)
                        .foregroundStyle(Color.muted)
                        .multilineTextAlignment(.leading)
                    if progress.cleared {
                        HStack(spacing: 8) {
                            Text(String(repeating: "★", count: progress.bestStars)
                                 + String(repeating: "☆", count: max(0, 3 - progress.bestStars)))
                                .foregroundStyle(Color.amber)
                            if progress.bestScore > 0 {
                                Text("Best \(progress.bestScore)")
                                    .foregroundStyle(Color.muted)
                            }
                        }
                        .font(.caption.weight(.semibold))
                    }
                }
                Spacer(minLength: 0)
                Image(systemName: unlocked ? "chevron.right" : "lock.fill")
                    .foregroundStyle(Color.muted)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 14).fill(Color.panel))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.line, lineWidth: 1))
            .opacity(unlocked ? 1 : 0.55)
        }
        .buttonStyle(.plain)
        .disabled(!unlocked)
        .accessibilityLabel(unlocked ? "Level \(number), \(level.title)" : "Level \(number), locked")
    }
}

#Preview {
    LevelSelectView(progress: ProgressStore.shared, onBack: {}, onPlay: { _ in })
}
