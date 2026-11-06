import SpriteKit
import UIKit

struct DecoySpec {
    /// Where the prize sits.
    let prize: Tile
    let correct: Decoy
    /// Noise made when the wrong weight goes down. A spike, not an instant fail.
    let wrongWeightNoise: Double
}

/// Pick a decoy from the shelf, then swap it for the toy on the bed.
@MainActor
final class DecoySwapSystem: Mechanic {
    let spec: DecoySpec

    private(set) var held: Decoy?
    private(set) var swapped = false

    private let prize = SKShapeNode(circleOfRadius: 5)

    init(spec: DecoySpec) {
        self.spec = spec
    }

    func reset(model: GameModel) {
        held = nil
        swapped = false
    }

    func taskCompleted(_ task: MorningTask, model: GameModel) {
        if let decoy = task.decoy { held = decoy }
        guard task == .swap else { return }
        swapped = true
        if held != spec.correct {
            model.emit(spec.wrongWeightNoise, at: model.tile)
            model.onNoise?(model.tile, spec.wrongWeightNoise)
            model.showToast("Wrong weight! The bed shifts…", bad: true)
            model.onEvent?(.loudCreak)
        }
    }

    func buildVisuals(in scene: HouseScene) {
        prize.strokeColor = .clear
        prize.position = scene.point(spec.prize)
        prize.zPosition = 6
        for side: CGFloat in [-1, 1] {
            let ear = SKShapeNode(ellipseOf: CGSize(width: 3, height: 8))
            ear.fillColor = UIColor(hex: 0xF4C7D8)
            ear.strokeColor = .clear
            ear.position = CGPoint(x: 3 * side, y: 6)
            prize.addChild(ear)
        }
        scene.addChild(prize)
    }

    func syncVisuals(in scene: HouseScene, time: TimeInterval) {
        prize.fillColor = swapped ? UIColor(hex: 0x8A8FA8) : UIColor(hex: 0xF4C7D8)
        for ear in prize.children { ear.isHidden = swapped }
    }
}
