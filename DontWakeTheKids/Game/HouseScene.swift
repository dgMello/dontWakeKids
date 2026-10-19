import SpriteKit
import UIKit

/// Draws the house from the model's state and turns taps into tiles.
final class HouseScene: SKScene {
    static let tileSize: CGFloat = 30
    private var T: CGFloat { Self.tileSize }

    private unowned let model: GameModel

    private let player = SKNode()
    private let playerFace = SKShapeNode(circleOfRadius: 5)
    private let tiptoeRing = SKShapeNode()
    private let progressArc = SKShapeNode()
    private var kidNodes: [(blanket: SKShapeNode, mark: SKLabelNode, base: CGPoint)] = []
    private let dogNode = SKNode()
    private let woofLabel = SKLabelNode(fontNamed: "AvenirNext-Heavy")
    private let dogNameLabel = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
    private let pathLayer = SKNode()
    private let creakLayer = SKNode()
    private let ringLayer = SKNode()
    private var highlights: [(station: Station, node: SKShapeNode)] = []
    private var checkMarks: [(item: ChecklistItem, node: SKLabelNode)] = []
    private let darkness = SKSpriteNode()
    private var shownCreaks: Set<Tile> = []
    private var lastPathVersion = -1
    private var lastUpdate: TimeInterval = 0

    init(model: GameModel) {
        self.model = model
        super.init(size: CGSize(width: CGFloat(House.cols) * Self.tileSize,
                                height: CGFloat(House.rows) * Self.tileSize))
        scaleMode = .aspectFit
        backgroundColor = Palette.wall
        buildHouse()
        model.onNoise = { [weak self] tile, amount in
            self?.spawnRing(at: tile, amount: amount)
        }
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) is not used")
    }

    /// Converts a tile coordinate (y down) to a scene point (y up), at the tile's center.
    private func point(_ x: Double, _ y: Double) -> CGPoint {
        CGPoint(x: (CGFloat(x) + 0.5) * T, y: (CGFloat(House.rows) - CGFloat(y) - 0.5) * T)
    }

    private func point(_ t: Tile) -> CGPoint { point(Double(t.x), Double(t.y)) }

    func resetVisuals() {
        creakLayer.removeAllChildren()
        ringLayer.removeAllChildren()
        shownCreaks = []
        lastPathVersion = -1
    }

    // MARK: - Building the house

    private func buildHouse() {
        for y in 0..<House.rows {
            for x in 0..<House.cols {
                let t = Tile(x: x, y: y)
                switch House.character(at: t) {
                case ".":
                    let floor = SKSpriteNode(color: Palette.floor(House.room(x: Double(x), y: Double(y))),
                                             size: CGSize(width: T, height: T))
                    floor.position = point(t)
                    floor.zPosition = 0
                    addChild(floor)
                    let seam = SKSpriteNode(color: UIColor(white: 1, alpha: 0.035), size: CGSize(width: T, height: 1))
                    seam.position = point(t)
                    seam.zPosition = 0.1
                    addChild(seam)
                case "F", "G":
                    let door = SKShapeNode(rectOf: CGSize(width: T - 6, height: T - 6), cornerRadius: 3)
                    door.fillColor = Palette.door
                    door.strokeColor = .clear
                    door.position = point(t)
                    door.zPosition = 3
                    addChild(door)
                    let knob = SKShapeNode(circleOfRadius: 2.5)
                    knob.fillColor = Palette.amber
                    knob.strokeColor = .clear
                    knob.position = CGPoint(x: House.character(at: t) == "F" ? 6 : -6, y: 0)
                    door.addChild(knob)
                    addHighlight(for: House.character(at: t) == "F" ? .leave : .dog,
                                 size: CGSize(width: T - 6, height: T - 6), at: point(t))
                default:
                    break
                }
            }
        }

        for label in House.roomLabels {
            let node = SKLabelNode(fontNamed: "ChalkboardSE-Regular")
            node.text = label.text
            node.fontSize = 13
            node.fontColor = UIColor(white: 0.92, alpha: 0.3)
            node.verticalAlignmentMode = .center
            node.position = point(label.x, label.y)
            node.zPosition = 1
            addChild(node)
        }

        for f in House.furniture {
            let size = CGSize(width: CGFloat(f.w) * T - 6, height: CGFloat(f.h) * T - 6)
            let center = point(Double(f.x) + Double(f.w) / 2 - 0.5, Double(f.y) + Double(f.h) / 2 - 0.5)
            let shape = SKShapeNode(rectOf: size, cornerRadius: 5)
            shape.fillColor = UIColor(hex: f.colorHex)
            shape.strokeColor = .clear
            shape.position = center
            shape.zPosition = 3
            addChild(shape)

            if f.kind == .bed {
                let pillow = SKShapeNode(rectOf: CGSize(width: size.width - 12, height: 10), cornerRadius: 4)
                pillow.fillColor = UIColor(hex: 0x5A6596)
                pillow.strokeColor = .clear
                pillow.position = CGPoint(x: 0, y: size.height / 2 - 10)
                shape.addChild(pillow)
            }
            if f.kind == .crib {
                shape.strokeColor = UIColor(hex: 0x8C98C8, alpha: 0.6)
                shape.lineWidth = 1.5
            }

            if !f.label.isEmpty {
                let label = SKLabelNode(fontNamed: "AvenirNext-Bold")
                label.text = f.label
                label.fontSize = 9
                label.fontColor = UIColor(white: 0.92, alpha: 0.75)
                label.verticalAlignmentMode = .center
                label.position = .zero
                shape.addChild(label)
            }

            if let station = f.station {
                addHighlight(for: station, size: size, at: center)
                if let item = MorningTask.tasks(for: station).first?.checklistItem {
                    let check = SKLabelNode(fontNamed: "AvenirNext-Heavy")
                    check.text = "✓"
                    check.fontSize = 12
                    check.fontColor = UIColor(hex: 0x9BE38F)
                    check.verticalAlignmentMode = .center
                    check.position = CGPoint(x: size.width / 2 - 6, y: size.height / 2 - 6)
                    check.isHidden = true
                    shape.addChild(check)
                    checkMarks.append((item, check))
                }
            }
        }

        creakLayer.zPosition = 2
        addChild(creakLayer)

        for sleeper in model.sleepers {
            let base = point(sleeper.x, sleeper.y)
            let blanket = SKShapeNode(rectOf: CGSize(width: T * 1.1, height: 16), cornerRadius: 6)
            blanket.fillColor = Palette.blanket(for: 0)
            blanket.strokeColor = .clear
            blanket.position = base
            blanket.zPosition = 5
            addChild(blanket)
            let head = SKShapeNode(circleOfRadius: 6)
            head.fillColor = Palette.skin
            head.strokeColor = .clear
            head.position = CGPoint(x: -T * 0.55 + 8, y: 0)
            blanket.addChild(head)
            let mark = SKLabelNode(fontNamed: "AvenirNext-Heavy")
            mark.text = "z"
            mark.fontSize = 12
            mark.verticalAlignmentMode = .center
            mark.zPosition = 6
            addChild(mark)
            kidNodes.append((blanket, mark, base))
        }

        buildDog()

        pathLayer.zPosition = 6
        addChild(pathLayer)
        ringLayer.zPosition = 7
        addChild(ringLayer)

        buildPlayer()

        darkness.texture = Self.makeDarknessTexture(size: CGSize(width: size.width * 2, height: size.height * 2))
        darkness.size = CGSize(width: size.width * 2, height: size.height * 2)
        darkness.zPosition = 50
        addChild(darkness)
    }

    private func addHighlight(for station: Station, size: CGSize, at center: CGPoint) {
        let ring = SKShapeNode(rectOf: size, cornerRadius: 5)
        ring.strokeColor = Palette.amber
        ring.fillColor = .clear
        ring.lineWidth = 2
        ring.position = center
        ring.zPosition = 4
        ring.isHidden = true
        addChild(ring)
        highlights.append((station, ring))
    }

    private func buildDog() {
        dogNode.position = point(House.dogBed)
        dogNode.zPosition = 5
        let bed = SKShapeNode(ellipseOf: CGSize(width: 26, height: 20))
        bed.fillColor = UIColor(hex: 0x5C4A6E)
        bed.strokeColor = .clear
        bed.position = CGPoint(x: 0, y: -2)
        dogNode.addChild(bed)
        let body = SKShapeNode(ellipseOf: CGSize(width: 18, height: 14))
        body.fillColor = UIColor(hex: 0xA8774C)
        body.strokeColor = .clear
        dogNode.addChild(body)
        for side: CGFloat in [-1, 1] {
            let ear = SKShapeNode(ellipseOf: CGSize(width: 6, height: 10))
            ear.fillColor = UIColor(hex: 0x7B5233)
            ear.strokeColor = .clear
            ear.position = CGPoint(x: 7 * side, y: 4)
            ear.zRotation = 0.4 * side
            dogNode.addChild(ear)
        }
        woofLabel.text = "WOOF"
        woofLabel.fontSize = 11
        woofLabel.fontColor = Palette.danger
        woofLabel.position = CGPoint(x: 0, y: 14)
        woofLabel.isHidden = true
        dogNode.addChild(woofLabel)
        dogNameLabel.text = "Pickles"
        dogNameLabel.fontSize = 9
        dogNameLabel.fontColor = UIColor(hex: 0xA0BEFF, alpha: 0.7)
        dogNameLabel.position = CGPoint(x: 0, y: -22)
        dogNode.addChild(dogNameLabel)
        addChild(dogNode)
    }

    private func buildPlayer() {
        player.zPosition = 8
        let dashed = CGPath(ellipseIn: CGRect(x: -13, y: -13, width: 26, height: 26), transform: nil)
        tiptoeRing.path = dashed.copy(dashingWithPhase: 0, lengths: [3, 3])
        tiptoeRing.strokeColor = Palette.calm
        tiptoeRing.lineWidth = 1
        player.addChild(tiptoeRing)
        let body = SKShapeNode(circleOfRadius: 9)
        body.fillColor = Palette.robe
        body.strokeColor = .clear
        player.addChild(body)
        playerFace.fillColor = Palette.skin
        playerFace.strokeColor = .clear
        player.addChild(playerFace)
        progressArc.strokeColor = Palette.amber
        progressArc.lineWidth = 3
        progressArc.lineCap = .round
        player.addChild(progressArc)
        addChild(player)
    }

    private static func makeDarknessTexture(size: CGSize) -> SKTexture {
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            let shade = UIColor(red: 6 / 255, green: 9 / 255, blue: 22 / 255, alpha: 1)
            let colors = [shade.withAlphaComponent(0).cgColor, shade.withAlphaComponent(0.7).cgColor] as CFArray
            guard let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1]) else { return }
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            context.cgContext.drawRadialGradient(gradient, startCenter: center, startRadius: 40,
                                                 endCenter: center, endRadius: 190,
                                                 options: [.drawsAfterEndLocation])
        }
        return SKTexture(image: image)
    }

    // MARK: - Effects

    private func spawnRing(at tile: Tile, amount: Double) {
        let radius = CGFloat(min(160, 14 + amount * 2.4))
        let ring = SKShapeNode(circleOfRadius: radius)
        ring.strokeColor = UIColor(hex: 0xFF826E)
        ring.fillColor = .clear
        ring.lineWidth = 2
        ring.position = point(tile)
        ring.alpha = CGFloat(min(1, 0.35 + amount / 40))
        ring.setScale(6 / radius)
        ringLayer.addChild(ring)
        let duration = TimeInterval(radius / 180)
        ring.run(.sequence([
            .group([.scale(to: 1, duration: duration), .fadeOut(withDuration: duration + 0.3)]),
            .removeFromParent(),
        ]))
    }

    // MARK: - Frame loop

    override func update(_ currentTime: TimeInterval) {
        let dt = lastUpdate == 0 ? 0 : min(0.05, currentTime - lastUpdate)
        lastUpdate = currentTime
        model.update(dt)
        sync(time: currentTime)
    }

    private func sync(time: TimeInterval) {
        let p = point(model.posX, model.posY)
        player.position = p
        playerFace.position = CGPoint(x: model.facing * 2, y: 1)
        tiptoeRing.isHidden = !model.tiptoe
        darkness.position = p

        if model.isBusy {
            let path = CGMutablePath()
            let start = CGFloat.pi / 2
            path.addArc(center: .zero, radius: 14, startAngle: start,
                        endAngle: start - .pi * 2 * CGFloat(model.activeProgress), clockwise: true)
            progressArc.path = path
            progressArc.isHidden = false
        } else {
            progressArc.isHidden = true
        }

        for (i, node) in kidNodes.enumerated() where i < model.sleepers.count {
            let meter = model.sleepers[i].meter
            node.blanket.fillColor = Palette.blanket(for: meter)
            if meter >= GameModel.stirLevel {
                node.mark.text = "!"
                node.mark.fontSize = 16
                node.mark.fontColor = Palette.danger
                node.mark.alpha = 1
                node.mark.position = CGPoint(x: node.base.x + 4, y: node.base.y + 16 + CGFloat(sin(time * 11)) * 2)
            } else {
                let z = CGFloat(time.truncatingRemainder(dividingBy: 0.9) / 0.9)
                node.mark.text = "z"
                node.mark.fontSize = 12
                node.mark.fontColor = UIColor(hex: 0xA0BEFF, alpha: 0.85)
                node.mark.alpha = 1 - z
                node.mark.position = CGPoint(x: node.base.x + 2 + z * 8, y: node.base.y + 10 + z * 14)
            }
        }

        dogNode.isHidden = !model.dogHere
        woofLabel.isHidden = model.dogBarkingFor <= 0
        dogNameLabel.isHidden = model.dogBarkingFor > 0

        if model.pathVersion != lastPathVersion {
            lastPathVersion = model.pathVersion
            pathLayer.removeAllChildren()
            for t in model.path {
                let dot = SKShapeNode(circleOfRadius: 2.5)
                dot.fillColor = Palette.amber.withAlphaComponent(0.35)
                dot.strokeColor = .clear
                dot.position = point(t)
                pathLayer.addChild(dot)
            }
        }

        let showHighlights = model.phase == .playing && !model.isBusy
        for h in highlights {
            h.node.isHidden = !(showHighlights && model.nearbyStations.contains(h.station))
        }
        for c in checkMarks {
            c.node.isHidden = !model.completed.contains(c.item)
        }

        for t in model.revealedCreaks where !shownCreaks.contains(t) {
            shownCreaks.insert(t)
            let crack = CGMutablePath()
            crack.move(to: CGPoint(x: -8, y: 6))
            crack.addLine(to: CGPoint(x: -1, y: 0))
            crack.addLine(to: CGPoint(x: -4, y: -4))
            crack.addLine(to: CGPoint(x: 7, y: -8))
            let mark = SKShapeNode(path: crack)
            mark.strokeColor = Palette.danger.withAlphaComponent(0.75)
            mark.lineWidth = 2
            mark.position = point(t)
            creakLayer.addChild(mark)
        }
    }

    // MARK: - Input

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        let x = Int(floor(location.x / T))
        let y = House.rows - 1 - Int(floor(location.y / T))
        model.tap(Tile(x: x, y: y))
    }
}
