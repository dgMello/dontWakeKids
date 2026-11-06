import Foundation

/// One rule system a level can switch on (creaky boards, a sweeping camera, a dog...).
/// `GameModel` keeps movement, noise and scoring, and calls each active mechanic at fixed points.
/// Every method has a do-nothing default, so a mechanic only implements what it needs.
@MainActor
protocol Mechanic: AnyObject {
    /// Called when a level starts or restarts.
    func reset(model: GameModel)
    /// Called every frame while playing.
    func update(_ dt: Double, model: GameModel)
    /// Called when the player arrives on a tile. Change `noise` to make the step louder or quieter.
    func playerStepped(onto tile: Tile, noise: inout Double, model: GameModel)
    /// Called when a task finishes.
    func taskCompleted(_ task: MorningTask, model: GameModel)
    /// Return false to hold the player still this frame (freezes, cameras).
    func canMove(model: GameModel) -> Bool
    /// Add this mechanic's nodes to the scene, once, when the scene is built.
    func buildVisuals(in scene: HouseScene)
    /// Update this mechanic's nodes every frame.
    func syncVisuals(in scene: HouseScene, time: TimeInterval)
}

extension Mechanic {
    func reset(model: GameModel) {}
    func update(_ dt: Double, model: GameModel) {}
    func playerStepped(onto tile: Tile, noise: inout Double, model: GameModel) {}
    func taskCompleted(_ task: MorningTask, model: GameModel) {}
    func canMove(model: GameModel) -> Bool { true }
    func buildVisuals(in scene: HouseScene) {}
    func syncVisuals(in scene: HouseScene, time: TimeInterval) {}
}

extension MechanicKind {
    @MainActor
    func make() -> Mechanic {
        switch self {
        case .pressurePlates: return PressurePlateSystem()
        case .decoySwap(let spec): return DecoySwapSystem(spec: spec)
        case .chase(let spec): return ChaseSystem(spec: spec)
        case .ripples(let spec): return RippleSystem(spec: spec)
        }
    }
}
