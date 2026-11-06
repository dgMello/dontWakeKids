import XCTest
@testable import DontWakeTheKids

/// The Phase 1 levels. Each one gets a scripted run from start to finish.
@MainActor
final class CampaignTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName = ""
    private let frame = 1.0 / 60

    override func setUp() async throws {
        suiteName = "CampaignTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() async throws {
        defaults.removePersistentDomain(forName: suiteName)
    }

    private func makeModel(_ level: LevelDefinition) -> GameModel {
        let model = GameModel(level: level, progress: ProgressStore(defaults: defaults))
        model.start()
        return model
    }

    private func walk(_ model: GameModel, to tile: Tile) {
        model.tap(tile)
        var t = 0.0
        while !model.path.isEmpty && t < 30 && model.phase == .playing {
            model.update(frame)
            t += frame
        }
    }

    /// Walks one straight leg at a time, so the route stays exactly as scripted.
    private func walk(_ model: GameModel, through tiles: [Tile]) {
        for tile in tiles { walk(model, to: tile) }
    }

    private func run(_ model: GameModel, seconds: Double) {
        var t = 0.0
        while t < seconds && model.phase == .playing {
            model.update(frame)
            t += frame
        }
    }

    private func result(_ model: GameModel) -> GameResult? {
        if case .over(let result) = model.phase { return result }
        return nil
    }

    // MARK: - L1: Raiders of the Lost Nap

    /// Tiptoe to the shelf and the bed, then walk out around the creaks.
    private func lostNapToTheBed(_ model: GameModel, pick: MorningTask) {
        model.tiptoe = true
        walk(model, to: Tile(x: 9, y: 2))
        XCTAssertTrue(model.availableTasks.contains(pick))
        model.perform(pick)
        run(model, seconds: 1.2)
        XCTAssertTrue(model.completed.contains(.decoy))

        walk(model, through: [Tile(x: 9, y: 7), Tile(x: 3, y: 7), Tile(x: 3, y: 4), Tile(x: 2, y: 4), Tile(x: 2, y: 2)])
        XCTAssertTrue(model.availableTasks.contains(.swap))
        model.perform(.swap)
        run(model, seconds: 2.2)
        XCTAssertTrue(model.completed.contains(.swap))
    }

    private let lostNapWayOut = [
        Tile(x: 2, y: 4), Tile(x: 3, y: 4), Tile(x: 3, y: 7), Tile(x: 6, y: 7), Tile(x: 6, y: 10),
        Tile(x: 5, y: 10), Tile(x: 5, y: 13),
    ]

    func testLostNapPerfectRunIsSilent() throws {
        let model = makeModel(.lostNap)
        lostNapToTheBed(model, pick: .pickSocks)

        model.tiptoe = false
        walk(model, through: lostNapWayOut)
        let chase = try XCTUnwrap(model.mechanic(ChaseSystem.self))
        XCTAssertFalse(chase.hasBumped)
        XCTAssertTrue(model.availableTasks.contains(.leave))
        model.perform(.leave)

        let end = try XCTUnwrap(result(model))
        XCTAssertTrue(end.won)
        XCTAssertEqual(end.stars, 3)
        XCTAssertEqual(end.title, "Silent")
        XCTAssertTrue(model.progress.progress(for: .lostNap).cleared)
    }

    /// The likely first try: careful on the way in, then tap the door and run.
    func testRunningStraightForTheDoorDoesNotLoseTheTutorial() throws {
        let model = makeModel(.lostNap)
        lostNapToTheBed(model, pick: .pickSocks)
        model.tiptoe = false
        walk(model, to: Tile(x: 5, y: 13))
        XCTAssertEqual(model.phase, .playing)
        model.perform(.leave)
        XCTAssertEqual(result(model)?.won, true)
    }

    func testTiptoeLosesTheRaceToTheBall() throws {
        let model = makeModel(.lostNap)
        lostNapToTheBed(model, pick: .pickSocks)
        walk(model, through: lostNapWayOut)   // still tiptoeing
        let chase = try XCTUnwrap(model.mechanic(ChaseSystem.self))
        XCTAssertTrue(chase.hasBumped)
    }

    /// Leaves room for a person to react: tap the door, then tap the exit button.
    func testWalkingBeatsTheBallWithTimeToSpare() throws {
        let spec = try XCTUnwrap(makeModel(.lostNap).mechanic(ChaseSystem.self)).spec
        let ballSeconds = spec.delay + spec.length / spec.speed
        let wayOutTiles = 16.0
        XCTAssertGreaterThan(ballSeconds - wayOutTiles / GameModel.walkSpeed, 2)
        XCTAssertLessThan(ballSeconds, wayOutTiles / GameModel.tiptoeSpeed)
    }

    func testBallBumpIsLoudButNotAnInstantLoss() throws {
        let model = makeModel(.lostNap)
        lostNapToTheBed(model, pick: .pickSocks)
        run(model, seconds: 7)
        XCTAssertEqual(model.phase, .playing)
        XCTAssertTrue(try XCTUnwrap(model.mechanic(ChaseSystem.self)).hasBumped)
        XCTAssertGreaterThan(model.sleepers[0].peak, 35)
    }

    func testWrongDecoyIsASpikeNotAFail() throws {
        for wrong in [MorningTask.pickTowel, .pickBeanbag] {
            let model = makeModel(.lostNap)
            lostNapToTheBed(model, pick: wrong)
            XCTAssertEqual(model.phase, .playing)
            XCTAssertGreaterThan(model.sleepers[0].peak, 35)
            XCTAssertLessThan(model.sleepers[0].peak, GameModel.stirLevel)
        }
    }

    func testTheBunnyComesBeforeTheDoor() {
        let model = makeModel(.lostNap)
        model.perform(.swap)
        XCTAssertFalse(model.isBusy)
        XCTAssertEqual(model.toast?.text, "Get a decoy from the shelf first")
        model.perform(.leave)
        XCTAssertEqual(model.phase, .playing)
        XCTAssertEqual(model.toast?.text, "You came for the bunny")
    }

    func testRestartPutsTheBallBack() throws {
        let model = makeModel(.lostNap)
        lostNapToTheBed(model, pick: .pickTowel)
        run(model, seconds: 2)
        model.start()
        let chase = try XCTUnwrap(model.mechanic(ChaseSystem.self))
        XCTAssertEqual(chase.traveled, 0)
        XCTAssertFalse(chase.isRolling)
        XCTAssertNil(model.mechanic(DecoySwapSystem.self)?.held)
        XCTAssertEqual(model.mechanic(DecoySwapSystem.self)?.swapped, false)
    }

    // MARK: - L4: Ripples

    /// A model whose stirs come on a fixed rhythm.
    private func makeRipples() throws -> (GameModel, RippleSystem) {
        let model = makeModel(.ripples)
        let ripples = try XCTUnwrap(model.mechanic(RippleSystem.self))
        ripples.pick = { $0.lowerBound }
        return (model, ripples)
    }

    private func run(_ model: GameModel, until done: () -> Bool) {
        var t = 0.0
        while !done() && t < 60 && model.phase == .playing {
            model.update(frame)
            t += frame
        }
    }

    func testRhythmIsTruckThenWarningThenStir() throws {
        let (model, ripples) = try makeRipples()
        XCTAssertEqual(ripples.state, .calm)
        run(model) { ripples.state != .calm }
        XCTAssertEqual(ripples.state, .truck)
        XCTAssertFalse(ripples.isRippling)
        run(model) { ripples.state == .calm }
        run(model) { ripples.state != .calm }
        XCTAssertEqual(ripples.state, .warning)
        XCTAssertTrue(ripples.isRippling)
        run(model) { ripples.state != .warning }
        XCTAssertEqual(ripples.state, .stirring)
        run(model) { ripples.state != .stirring }
        XCTAssertEqual(ripples.state, .calm)
    }

    func testStandingStillThroughAStirCostsNothing() throws {
        let (model, ripples) = try makeRipples()
        run(model) { ripples.state == .stirring }
        run(model) { ripples.state == .calm }
        XCTAssertEqual(model.sleepers[0].peak, 0)
    }

    func testWalkingThroughAStirWakesMaya() throws {
        let (model, ripples) = try makeRipples()
        run(model) { ripples.state == .stirring }
        var target = 0
        let ends = [Tile(x: 12, y: 13), Tile(x: 1, y: 13)]
        run(model) {
            if model.path.isEmpty {
                model.tap(ends[target % 2])
                target += 1
            }
            return ripples.state != .stirring
        }
        let end = try XCTUnwrap(result(model))
        XCTAssertFalse(end.won)
        XCTAssertEqual(end.title, "Maya is up")
    }

    func testMovingDuringTheWarningOrTheTruckIsFree() throws {
        let (model, ripples) = try makeRipples()
        model.tiptoe = true
        var far = false
        run(model) {
            if model.path.isEmpty {
                model.tap(far ? Tile(x: 2, y: 13) : Tile(x: 3, y: 13))
                far.toggle()
            }
            return ripples.state == .stirring
        }
        XCTAssertLessThan(model.sleepers[0].peak, 10)
    }

    func testATaskDuringAStirIsLoud() throws {
        let (model, ripples) = try makeRipples()
        model.tiptoe = true
        walk(model, to: Tile(x: 11, y: 2))
        run(model) { ripples.state == .stirring }
        model.perform(.book)
        run(model, seconds: 1.5)
        XCTAssertGreaterThan(model.sleepers[0].peak, 10)
    }

    func testFreezeStopsWithinOneStep() {
        let model = makeModel(.ripples)
        model.tap(Tile(x: 12, y: 13))
        run(model, seconds: 0.1)
        model.stopWalking()
        XCTAssertEqual(model.path.count, 1)
        run(model, seconds: 0.5)
        XCTAssertTrue(model.path.isEmpty)
        XCTAssertEqual(model.tile, Tile(x: 3, y: 13))

        model.stopWalking()   // already still
        XCTAssertTrue(model.path.isEmpty)
    }

    /// Follows the rule the level teaches, at random stir times: freeze on rings, go when they stop.
    func testRipplesPerfectRunIsSilent() throws {
        for _ in 0..<5 {
            let model = makeModel(.ripples)
            let ripples = try XCTUnwrap(model.mechanic(RippleSystem.self))
            model.tiptoe = true

            func go(to tile: Tile) {
                var t = 0.0
                while model.tile != tile && t < 120 && model.phase == .playing {
                    if ripples.isRippling {
                        model.stopWalking()
                    } else if model.path.isEmpty {
                        model.tap(tile)
                    }
                    model.update(frame)
                    t += frame
                }
                XCTAssertEqual(model.tile, tile)
            }

            go(to: Tile(x: 11, y: 2))
            run(model) { !ripples.isRippling && ripples.state != .truck }
            XCTAssertTrue(model.availableTasks.contains(.book))
            model.perform(.book)
            run(model) { !model.isBusy }
            if !model.completed.contains(.book) {
                run(model) { !ripples.isRippling }
                model.perform(.book)
                run(model) { !model.isBusy }
            }
            XCTAssertTrue(model.completed.contains(.book))

            go(to: Tile(x: 2, y: 13))
            XCTAssertTrue(model.availableTasks.contains(.leave))
            model.perform(.leave)
            let end = try XCTUnwrap(result(model))
            XCTAssertTrue(end.won)
            XCTAssertEqual(end.stars, 3)
        }
    }

    func testNotWithoutTheBook() {
        let model = makeModel(.ripples)
        model.perform(.leave)
        XCTAssertEqual(model.phase, .playing)
        XCTAssertEqual(model.toast?.text, "Not without the library book")
    }

    // MARK: - Unlocks

    func testCampaignUnlocksInOrderAndClassicIsAlwaysOpen() {
        let store = ProgressStore(defaults: defaults)
        XCTAssertTrue(store.isUnlocked(.lostNap))
        XCTAssertFalse(store.isUnlocked(.ripples))
        XCTAssertTrue(store.isUnlocked(.classicMorning))
        store.recordWin(.lostNap, stars: 3, score: 900)
        XCTAssertTrue(store.isUnlocked(.ripples))
    }

    // MARK: - Level data

    func testChaseRouteRunsAlongOpenFloor() throws {
        let model = makeModel(.lostNap)
        let path = try XCTUnwrap(model.mechanic(ChaseSystem.self)).spec.path
        for (a, b) in zip(path, path.dropFirst()) {
            XCTAssertTrue(a.x == b.x || a.y == b.y, "leg \(a) to \(b) is not straight")
            var t = a
            while t != b {
                XCTAssertTrue(LevelDefinition.lostNap.isFloor(t), "\(t) is not floor")
                t.x += (b.x - a.x).signum()
                t.y += (b.y - a.y).signum()
            }
        }
        XCTAssertTrue(path.last.map { $0.neighbors.contains(LevelDefinition.lostNap.frontDoor!) } ?? false)
    }

    func testLostNapWayOutAvoidsEveryCreak() {
        let plates = LevelDefinition.lostNap.pressurePlates
        var at = Tile(x: 2, y: 2)
        for corner in lostNapWayOut {
            while at != corner {
                at.x += (corner.x - at.x).signum()
                at.y += (corner.y - at.y).signum()
                XCTAssertFalse(plates.contains(at), "\(at) creaks")
            }
        }
    }
}
