import SpriteKit
import UIKit

struct RippleSpec {
    /// The glass of water that gives the warning.
    let glass: Tile
    /// The fake: a truck shakes the glass this many seconds in, with no stir behind it.
    let truckAt: Double
    let truckLength: Double
    /// Seconds of calm between events.
    let calmGap: ClosedRange<Double>
    /// Seconds of ripples before moving starts to cost you.
    let warning: Double
    /// How long the kid stirs.
    let stirLength: ClosedRange<Double>
    /// Noise added by each step during a stir.
    let stepPenalty: Double
    /// Noise added per second by a task during a stir.
    let taskPenaltyPerSecond: Double
}

/// A glass of water warns you when a kid starts to stir. Moving during the stir is very loud.
/// Nothing holds the player still: stopping is the player's job, and that's the skill.
@MainActor
final class RippleSystem: Mechanic {
    enum State: Equatable {
        case calm, truck, warning, stirring
    }

    let spec: RippleSpec
    /// Picks a time from a range. Tests replace this to get a fixed rhythm.
    var pick: (ClosedRange<Double>) -> Double = { Double.random(in: $0) }

    private(set) var state = State.calm
    private var timer = 0.0
    private var truckDone = false
    private var warnedOnce = false

    private let glass = SKShapeNode(rectOf: CGSize(width: 10, height: 13), cornerRadius: 2)
    private var rings: [SKShapeNode] = []

    init(spec: RippleSpec) {
        self.spec = spec
    }

    /// True whenever the glass shows real ripples, including the warning.
    var isRippling: Bool { state == .warning || state == .stirring }

    func reset(model: GameModel) {
        state = .calm
        timer = spec.truckAt
        truckDone = false
        warnedOnce = false
    }

    func update(_ dt: Double, model: GameModel) {
        timer -= dt
        if timer <= 0 { advance(model: model) }
        if state == .stirring && model.isBusy {
            model.emit(spec.taskPenaltyPerSecond * dt, at: model.tile)
        }
    }

    private func advance(model: GameModel) {
        switch state {
        case .calm:
            if truckDone {
                state = .warning
                timer = spec.warning
                if !warnedOnce {
                    warnedOnce = true
                    model.showToast("Ripples! Freeze!", bad: true)
                }
            } else {
                truckDone = true
                state = .truck
                timer = spec.truckLength
                model.showToast("Just a truck going by")
            }
            model.onEvent?(.rumble)
        case .truck:
            state = .calm
            timer = pick(spec.calmGap)
        case .warning:
            state = .stirring
            timer = pick(spec.stirLength)
        case .stirring:
            state = .calm
            timer = pick(spec.calmGap)
        }
    }

    func playerStepped(onto tile: Tile, noise: inout Double, model: GameModel) {
        guard state == .stirring else { return }
        noise += spec.stepPenalty
        model.onNoise?(tile, spec.stepPenalty)
        model.showToast("\(model.level.sleepers.first?.name ?? "The kid") heard that!", bad: true)
        model.onEvent?(.loudCreak)
    }

    func buildVisuals(in scene: HouseScene) {
        // Above the darkness: the warning has to read from across the room.
        glass.fillColor = UIColor(hex: 0x8FC4E8, alpha: 0.85)
        glass.strokeColor = UIColor(white: 1, alpha: 0.8)
        glass.lineWidth = 1
        glass.position = scene.point(spec.glass)
        glass.zPosition = 51
        scene.addChild(glass)
        for _ in 0..<2 {
            let ring = SKShapeNode(circleOfRadius: 20)
            ring.strokeColor = Palette.calm
            ring.fillColor = .clear
            ring.lineWidth = 2
            ring.position = scene.point(spec.glass)
            ring.zPosition = 51
            ring.isHidden = true
            scene.addChild(ring)
            rings.append(ring)
        }
    }

    func syncVisuals(in scene: HouseScene, time: TimeInterval) {
        let base = scene.point(spec.glass)
        // A truck rattles the glass sideways. Only a stirring kid makes rings.
        glass.position = state == .truck
            ? CGPoint(x: base.x + CGFloat(sin(time * 50)) * 2, y: base.y)
            : base
        for (i, ring) in rings.enumerated() {
            ring.isHidden = !isRippling
            guard isRippling else { continue }
            let phase = (time / 0.8 + Double(i) * 0.5).truncatingRemainder(dividingBy: 1)
            ring.setScale(CGFloat(0.3 + phase * 0.9))
            ring.alpha = CGFloat(1 - phase)
        }
    }
}
