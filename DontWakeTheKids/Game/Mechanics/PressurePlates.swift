import SpriteKit
import UIKit

/// Creaky floorboards. Hidden until you step on one; then it stays marked with a crack.
@MainActor
final class PressurePlateSystem: Mechanic {
    static let tiptoeNoise = 12.0
    static let walkNoise = 32.0

    private(set) var plates: Set<Tile> = []
    private(set) var revealed: Set<Tile> = []

    private let layer = SKNode()
    private var drawn: Set<Tile> = []

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
    }

    func syncVisuals(in scene: HouseScene, time: TimeInterval) {
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
