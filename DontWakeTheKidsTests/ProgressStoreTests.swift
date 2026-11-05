import XCTest
@testable import DontWakeTheKids

@MainActor
final class ProgressStoreTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName = ""

    override func setUp() async throws {
        suiteName = "ProgressStoreTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() async throws {
        defaults.removePersistentDomain(forName: suiteName)
    }

    func testFirstLevelIsAlwaysUnlocked() {
        let store = ProgressStore(defaults: defaults)
        XCTAssertTrue(store.isUnlocked(LevelDefinition.all[0].id))
    }

    func testWinIsSavedAndReloaded() {
        let store = ProgressStore(defaults: defaults)
        XCTAssertTrue(store.recordWin(.classicMorning, stars: 2, score: 500))
        XCTAssertFalse(store.recordWin(.classicMorning, stars: 3, score: 400))

        let reloaded = ProgressStore(defaults: defaults)
        let p = reloaded.progress(for: .classicMorning)
        XCTAssertTrue(p.cleared)
        XCTAssertEqual(p.bestStars, 3)
        XCTAssertEqual(p.bestScore, 500)
    }

    func testOldBestScoreIsCarriedOver() {
        defaults.set(730, forKey: "bestScore")
        let store = ProgressStore(defaults: defaults)
        XCTAssertEqual(store.progress(for: .classicMorning).bestScore, 730)
    }
}
