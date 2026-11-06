import SpriteKit
import UIKit

/// Creaky floorboards. Hidden until you step on one; then it stays marked with a crack.
/// In a tutorial level (`platesVisible`) they shimmer until then.
@MainActor
final class PressurePlateSystem: Mechanic {
    static let tiptoeNoise = 12.0
    static let walkNoise = 32.0

    private(set) var plates: Set<Tile> = []
    private(set) var revealed: Set<Tile> = []

    private let layer = SKNode()
    private var drawn: Set<Tile> = []
    private var shimmers: [Tile: SKShapeNode] = [:]

    func reset(model: GameModel) {
        plates = model.level.pressurePlates
        revealed = []
        drawn = []
        layer.removeAllChildren()
    }

    func playerStepped(onto tile: Tile, noise: inout Double, model: GameModel) {
        guard plates.contains(tile) else { return }
        revealed.insert(tile)
        noise = model.tiptoe ? Self.tiptoeNoise : Self.walkNoise
        model.showToast(model.tiptoe ? "creak…" : "CREEEAK!", bad: !model.tiptoe)
        model.onNoise?(tile, noise)
        model.onEvent?(model.tiptoe ? .softCreak : .loudCreak)
    }

    func buildVisuals(in scene: HouseScene) {
        layer.zPosition = 2
        scene.addChild(layer)
        guard scene.level.platesVisible else { return }
        for t in scene.level.pressurePlates {
            let size = CGSize(width: HouseScene.tileSize - 4, height: HouseScene.tileSize - 4)
            let shimmer = SKShapeNode(rectOf: size, cornerRadius: 3)
            shimmer.fillColor = Palette.amber.withAlphaComponent(0.3)
            shimmer.strokeColor = Palette.amber
            shimmer.lineWidth = 1.5
            shimmer.position = scene.point(t)
            shimmer.zPosition = 51   // above the darkness, so the route can be planned
            scene.addChild(shimmer)
            shimmers[t] = shimmer
        }
    }

    func syncVisuals(in scene: HouseScene, time: TimeInterval) {
        for (t, shimmer) in shimmers {
            shimmer.isHidden = revealed.contains(t)
            shimmer.alpha = CGFloat(0.8 + 0.2 * sin(time * 3))
        }
        for t in revealed where !drawn.contains(t) {
            drawn.insert(t)
            let crack = CGMutablePath()
            crack.move(to: CGPoint(x: -8, y: 6))
            crack.addLine(to: CGPoint(x: -1, y: 0))
            crack.addLine(to: CGPoint(x: -4, y: -4))
            crack.addLine(to: CGPoint(x: 7, y: -8))
            let mark = SKShapeNode(path: crack)
            mark.strokeColor = Palette.danger.withAlphaComponent(0.75)
            mark.lineWidth = 2
            mark.position = scene.point(t)
            layer.addChild(mark)
        }
    }
}
