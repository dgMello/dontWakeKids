import SwiftUI
import UIKit

struct MeterView: View {
    let name: String
    let value: Double

    private var state: String {
        if value >= GameModel.stirLevel { return "stirring!" }
        if value >= 35 { return "restless" }
        return "asleep"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(name).fontWeight(.bold).foregroundStyle(Color.ink)
                Spacer()
                Text(state).foregroundStyle(value >= GameModel.stirLevel ? Color.danger : Color.muted)
            }
            .font(.caption)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.panel)
                    Capsule()
                        .fill(Palette.meterColor(for: value))
                        .frame(width: geo.size.width * CGFloat(min(100, value) / 100))
                }
                .overlay(Capsule().stroke(Color.line, lineWidth: 1))
            }
            .frame(height: 10)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(name), \(state)")
    }
}

/// The yellow sticky note on the fridge, in Dad's handwriting.
struct ChecklistNote: View {
    let completed: Set<ChecklistItem>

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), alignment: .leading), count: 3), alignment: .leading, spacing: 2) {
            ForEach(ChecklistItem.allCases) { item in
                let isDone = completed.contains(item)
                Text((isDone ? "✓ " : "☐ ") + item.label)
                    .font(Fonts.hand(15))
                    .strikethrough(isDone)
                    .opacity(isDone ? 0.55 : 1)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
        .foregroundStyle(Color.noteInk)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.note)
        .rotationEffect(.degrees(-0.6))
        .shadow(color: .black.opacity(0.35), radius: 7, y: 5)
    }
}

struct TaskButton: View {
    let task: MorningTask
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 2) {
                Text(task.name)
                    .font(.subheadline.weight(.heavy))
                    .foregroundStyle(Color.ink)
                Text(task.duration > 0 ? "\(task.detail) · \(Int(task.duration))s" : task.detail)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(task.isLoud ? Color.danger : Color.muted)
            }
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
        }
        .buttonStyle(GameButtonStyle())
    }
}

struct GameButtonStyle: ButtonStyle {
    var highlighted = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(highlighted ? Color.calm : Color.ink)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(highlighted ? Color(uiColor: UIColor(hex: 0x24305E)) : Color.panel)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(highlighted ? Color.calm : Color.line, lineWidth: 1)
            )
            .opacity(configuration.isPressed ? 0.75 : 1)
    }
}

struct PrimaryButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.body.weight(.heavy))
                .foregroundStyle(Color(uiColor: UIColor(hex: 0x2A1D05)))
                .padding(.horizontal, 22)
                .frame(minHeight: 48)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color.amber))
        }
    }
}

struct OverlayCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        ZStack {
            Color.night.opacity(0.92)
            VStack(spacing: 12) {
                content
            }
            .multilineTextAlignment(.center)
            .padding(20)
        }
    }
}
