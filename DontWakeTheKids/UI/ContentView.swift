import SpriteKit
import UIKit
import SwiftUI

struct ContentView: View {
    @StateObject private var model = GameModel()

    var body: some View {
        ZStack {
            Color.night.ignoresSafeArea()
            VStack(spacing: 10) {
                header
                HStack(spacing: 12) {
                    MeterView(name: "Baby", value: model.meters[0])
                    MeterView(name: "Maya, 8", value: model.meters[1])
                }
                ChecklistNote(completed: model.completed)
                board
                controls
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .preferredColorScheme(.dark)
        .onAppear {
            model.onEvent = { Haptics.play($0) }
            UIApplication.shared.isIdleTimerDisabled = true
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("Don't Wake the Kids")
                .font(Fonts.hand(26, bold: true))
                .foregroundStyle(Color.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 0) {
                Text("TRAIN AT 6:15")
                    .font(.caption2.weight(.semibold))
                    .tracking(0.8)
                    .foregroundStyle(Color.muted)
                Text(model.clockText)
                    .font(.system(.title3, design: .rounded).weight(.heavy))
                    .monospacedDigit()
                    .foregroundStyle(Color.amber)
            }
        }
    }

    private var board: some View {
        SpriteView(scene: model.scene, preferredFramesPerSecond: 60)
            .aspectRatio(CGFloat(House.cols) / CGFloat(House.rows), contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.line, lineWidth: 1))
            .overlay(alignment: .top) { toastView }
            .overlay { phaseOverlay }
            .frame(maxWidth: .infinity)
            .layoutPriority(1)
    }

    @ViewBuilder private var toastView: some View {
        if let toast = model.toast {
            Text(toast.text)
                .font(.footnote.weight(.heavy))
                .foregroundStyle(toast.isBad ? Color.danger : Color.ink)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Capsule().fill(Color.night.opacity(0.9)))
                .overlay(Capsule().stroke(toast.isBad ? Color.danger : Color.line, lineWidth: 1))
                .padding(.top, 10)
                .id(toast.id)
                .transition(.opacity)
                .allowsHitTesting(false)
        }
    }

    @ViewBuilder private var phaseOverlay: some View {
        switch model.phase {
        case .intro:
            OverlayCard {
                Text("5:30 AM. Shhh.")
                    .font(Fonts.hand(34, bold: true))
                    .foregroundStyle(Color.amber)
                Text("Get through your morning and out the front door by 6:15 without waking the baby or Maya.")
                    .foregroundStyle(Color.ink)
                Text("Tap the floor to walk. Stand next to the closet, sink, shower, coffee, fridge or back door to do a task. Tiptoe is quiet but slow. Some floorboards creak, and Pickles the dog barks if you stomp past.")
                    .font(.footnote)
                    .foregroundStyle(Color.muted)
                PrimaryButton(title: "Start my morning") { model.start() }
            }
        case .playing:
            EmptyView()
        case .over(let result):
            OverlayCard {
                Text(result.title)
                    .font(Fonts.hand(34, bold: true))
                    .foregroundStyle(Color.amber)
                if result.won {
                    Text(String(repeating: "★", count: result.stars) + String(repeating: "☆", count: 3 - result.stars))
                        .font(.system(size: 30))
                        .foregroundStyle(Color.amber)
                }
                Text(result.text)
                    .foregroundStyle(Color.ink)
                Text(result.stats)
                    .font(.footnote)
                    .foregroundStyle(Color.muted)
                if result.isNewBest {
                    Text("New best score")
                        .font(.footnote.weight(.heavy))
                        .foregroundStyle(Color.amber)
                } else if model.bestScore > 0 {
                    Text("Best score \(model.bestScore)")
                        .font(.footnote)
                        .foregroundStyle(Color.muted)
                }
                PrimaryButton(title: "Try again") { model.start() }
            }
        }
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Button {
                    model.tiptoe.toggle()
                } label: {
                    Label(model.tiptoe ? "Tiptoe on" : "Tiptoe off", systemImage: "shoeprints.fill")
                        .font(.body.weight(.heavy))
                        .frame(maxWidth: .infinity, minHeight: 48)
                }
                .buttonStyle(GameButtonStyle(highlighted: model.tiptoe))

                if let task = model.activeTask {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(task.name + "…")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(Color.ink)
                        ProgressView(value: model.activeProgress)
                            .tint(Color.amber)
                    }
                    .frame(maxWidth: .infinity)
                    Button("Stop") { model.stopTask() }
                        .font(.body.weight(.heavy))
                        .frame(minHeight: 48)
                        .buttonStyle(GameButtonStyle())
                }
            }

            if model.activeTask == nil {
                if model.availableTasks.isEmpty {
                    Text(model.phase == .playing ? "Walk up to something to use it." : " ")
                        .font(.subheadline)
                        .foregroundStyle(Color.muted)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                        ForEach(model.availableTasks) { task in
                            TaskButton(task: task) { model.perform(task) }
                        }
                    }
                }
            }
        }
        .frame(height: 124, alignment: .top)
    }
}

#Preview {
    ContentView()
}
