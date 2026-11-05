import XCTest
@testable import DontWakeTheKids

@MainActor
final class GameModelTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName = ""

    override func setUp() async throws {
        suiteName = "GameModelTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() async throws {
        defaults.removePersistentDomain(forName: suiteName)
    }

    private func makeModel() -> GameModel {
        let model = GameModel(level: .classicMorning, progress: ProgressStore(defaults: defaults))
        model.start()
        return model
    }

    /// Runs frames until the player stops walking, or the time limit passes.
    private func walk(_ model: GameModel, to tile: Tile, limit: Double = 30) {
        model.tap(tile)
        var t = 0.0
        while !model.path.isEmpty && t < limit && model.phase == .playing {
            model.update(0.05)
            t += 0.05
        }
    }

    private func run(_ model: GameModel, seconds: Double) {
        var t = 0.0
        while t < seconds && model.phase == .playing {
            model.update(0.05)
            t += 0.05
        }
    }

    func testStartsFromLevelData() {
        let model = makeModel()
        XCTAssertEqual(model.tile, LevelDefinition.classicMorning.start)
        XCTAssertEqual(model.sleepers.map(\.id), ["baby", "maya"])
        XCTAssertEqual(model.meters, [0, 0])
        XCTAssertTrue(model.dogHere)
        XCTAssertEqual(model.clockText, "5:30 AM")
        XCTAssertNotNil(model.mechanic(PressurePlateSystem.self))
    }

    func testCreakyBoardIsRevealedAndWakesTheBaby() {
        let model = makeModel()
        let creak = Tile(x: 3, y: 3)
        XCTAssertTrue(LevelDefinition.classicMorning.pressurePlates.contains(creak))
        walk(model, to: creak)
        XCTAssertEqual(model.tile, creak)
        XCTAssertTrue(model.mechanic(PressurePlateSystem.self)?.revealed.contains(creak) ?? false)
        XCTAssertGreaterThan(model.sleepers[0].meter, 10)
    }

    func testTiptoeIsQuieterThanWalking() {
        let loud = makeModel()
        walk(loud, to: Tile(x: 3, y: 3))
        let quiet = makeModel()
        quiet.tiptoe = true
        walk(quiet, to: Tile(x: 3, y: 3))
        XCTAssertLessThan(quiet.sleepers[0].peak, loud.sleepers[0].peak)
    }

    func testCannotLeaveInPajamas() {
        let model = makeModel()
        model.perform(.leave)
        XCTAssertEqual(model.phase, .playing)
        XCTAssertEqual(model.toast?.text, "You can't leave in pajamas")
    }

    func testRestartClearsTheLevel() {
        let model = makeModel()
        walk(model, to: Tile(x: 3, y: 3))
        model.start()
        XCTAssertEqual(model.tile, LevelDefinition.classicMorning.start)
        XCTAssertEqual(model.sleepers[0].meter, 0)
        XCTAssertEqual(model.mechanic(PressurePlateSystem.self)?.revealed, [])
    }

    func testMissingTheTrain() {
        let model = makeModel()
        run(model, seconds: 100)
        guard case .over(let result) = model.phase else { return XCTFail("still playing") }
        XCTAssertFalse(result.won)
        XCTAssertEqual(result.title, "Missed the train")
    }

    /// Get dressed, then walk out the front door, tiptoeing the whole way.
    func testScriptedWinIsRecorded() {
        let progress = ProgressStore(defaults: defaults)
        let model = GameModel(level: .classicMorning, progress: progress)
        model.start()
        model.tiptoe = true

        walk(model, to: Tile(x: 4, y: 1))   // the closet
        XCTAssertTrue(model.availableTasks.contains(.dress))
        model.perform(.dress)
        run(model, seconds: 3.5)
        XCTAssertTrue(model.completed.contains(.dress))

        walk(model, to: Tile(x: 4, y: 14))  // the front door
        XCTAssertTrue(model.availableTasks.contains(.leave))
        model.perform(.leave)

        guard case .over(let result) = model.phase else { return XCTFail("still playing") }
        XCTAssertTrue(result.won)
        XCTAssertGreaterThanOrEqual(result.stars, 1)
        XCTAssertTrue(result.isNewBest)
        XCTAssertTrue(progress.progress(for: .classicMorning).cleared)
        XCTAssertEqual(progress.progress(for: .classicMorning).bestScore, result.score)
    }
}
