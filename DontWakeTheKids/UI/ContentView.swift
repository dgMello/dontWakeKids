import SpriteKit
import UIKit
import SwiftUI

struct ContentView: View {
    @StateObject private var model: GameModel
    private let onExit: () -> Void

    init(level: LevelDefinition = .classicMorning, onExit: @escaping () -> Void = {}) {
        _model = StateObject(wrappedValue: GameModel(level: level))
        self.onExit = onExit
    }

    var body: some View {
        ZStack {
            Color.night.ignoresSafeArea()
            VStack(spacing: 10) {
                header
                HStack(spacing: 12) {
                    ForEach(Array(model.level.sleepers.enumerated()), id: \.element.id) { i, sleeper in
                        MeterView(name: sleeper.meterLabel, value: i < model.meters.count ? model.meters[i] : 0)
                    }
                }
                if !model.level.checklist.isEmpty {
                    ChecklistNote(items: model.level.checklist, completed: model.completed)
                }
                board
                controls
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .preferredColorScheme(.dark)
        .onAppear {
            SoundEffects.preload()
            model.onEvent = { event in
                Haptics.play(event)
                SoundEffects.play(event)
            }
            UIApplication.shared.isIdleTimerDisabled = true
        }
        .onChange(of: model.activeTask) { _, task in
            SoundEffects.taskChanged(to: task)
        }
        .onDisappear {
            SoundEffects.stopTaskSound()
        }
    }

    private var header: some View {
        HStack(alignment: .center) {
            Button(action: onExit) {
                Image(systemName: "chevron.left")
                    .font(.body.weight(.heavy))
                    .foregroundStyle(Color.muted)
                    .frame(width: 32, height: 44)
            }
            .accessibilityLabel("Levels")
            Text(model.level.title)
                .font(Fonts.hand(26, bold: true))
                .foregroundStyle(Color.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Spacer(minLength: 8)
            if let clock = model.level.clock {
                VStack(alignment: .trailing, spacing: 0) {
                    Text(clock.deadlineLabel)
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
    }

    private var board: some View {
        SpriteView(scene: model.scene, preferredFramesPerSecond: 60)
            .aspectRatio(CGFloat(model.level.cols) / CGFloat(model.level.rows), contentMode: .fit)
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
                Text(model.level.intro.title)
                    .font(Fonts.hand(34, bold: true))
                    .foregroundStyle(Color.amber)
                Text(model.level.intro.text)
                    .foregroundStyle(Color.ink)
                Text(model.level.intro.hint)
                    .font(.footnote)
                    .foregroundStyle(Color.muted)
                PrimaryButton(title: model.level.intro.startButton) { model.start() }
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
                Button("Back to levels", action: onExit)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.muted)
                    .frame(minHeight: 44)
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

                if model.mechanic(RippleSystem.self) != nil, model.activeTask == nil {
                    Button {
                        model.stopWalking()
                    } label: {
                        Label("Freeze", systemImage: "hand.raised.fill")
                            .font(.body.weight(.heavy))
                            .frame(maxWidth: .infinity, minHeight: 48)
                    }
                    .buttonStyle(GameButtonStyle())
                }

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
                            TaskButton(task: task, title: task == .leave ? model.level.exitName : nil) {
                                model.perform(task)
                            }
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
