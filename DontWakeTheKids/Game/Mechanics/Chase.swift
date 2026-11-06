import SpriteKit
import UIKit

/// Something that starts moving once a checklist item is done and must be beaten to the end of its path.
struct ChaseSpec {
    /// Corners of the route. Each leg runs straight along a row or column.
    let path: [Tile]
    /// Tiles per second. Sits between tiptoe and walking speed so tiptoeing loses the race.
    let speed: Double
    /// The chase starts when this is done.
    let trigger: ChecklistItem
    /// Seconds between the trigger and the first roll.
    let delay: Double
    /// Noise made when it reaches the end.
    let bumpNoise: Double

    var length: Double {
        zip(path, path.dropFirst()).reduce(0) { total, leg in
            total + hypot(Double(leg.1.x - leg.0.x), Double(leg.1.y - leg.0.y))
        }
    }
}

/// A toy ball rolling along a fixed route. If it gets to the end first it bumps the door.
@MainActor
final class ChaseSystem: Mechanic {
    let spec: ChaseSpec

    private(set) var traveled = 0.0
    private(set) var isRolling = false
    private(set) var hasBumped = false
    private var waited = 0.0

    private let ball = SKShapeNode(circleOfRadius: 7)

    init(spec: ChaseSpec) {
        self.spec = spec
    }

    /// Where the ball is now, in tile coordinates.
    var position: (x: Double, y: Double) {
        var left = traveled
        for (a, b) in zip(spec.path, spec.path.dropFirst()) {
            let dx = Double(b.x - a.x)
            let dy = Double(b.y - a.y)
            let leg = hypot(dx, dy)
            if left <= leg, leg > 0 {
                return (Double(a.x) + dx / leg * left, Double(a.y) + dy / leg * left)
            }
            left -= leg
        }
        let end = spec.path.last ?? Tile(x: 0, y: 0)
        return (Double(end.x), Double(end.y))
    }

    func reset(model: GameModel) {
        traveled = 0
        isRolling = false
        hasBumped = false
        waited = 0
    }

    func update(_ dt: Double, model: GameModel) {
        guard !hasBumped, model.completed.contains(spec.trigger) else { return }
        if !isRolling {
            waited += dt
            guard waited >= spec.delay else { return }
            isRolling = true
            model.showToast("The ball is rolling! Beat it to the door!", bad: true)
            model.onEvent?(.rumble)
        }
        traveled += spec.speed * dt
        if traveled >= spec.length {
            traveled = spec.length
            isRolling = false
            hasBumped = true
            let end = spec.path.last ?? model.tile
            model.emit(spec.bumpNoise, at: end)
            model.onNoise?(end, spec.bumpNoise)
            model.showToast("THUD! The ball hit the door", bad: true)
            model.onEvent?(.thud)
        }
    }

    func buildVisuals(in scene: HouseScene) {
        ball.fillColor = UIColor(hex: 0xE2574C)
        ball.strokeColor = UIColor(white: 1, alpha: 0.7)
        ball.lineWidth = 1.5
        ball.zPosition = 51   // above the darkness, so the race is always readable
        scene.addChild(ball)
    }

    func syncVisuals(in scene: HouseScene, time: TimeInterval) {
        let p = position
        ball.position = scene.point(p.x, p.y)
        ball.zRotation = CGFloat(-traveled)
    }
}
