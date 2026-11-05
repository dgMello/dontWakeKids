import XCTest
@testable import DontWakeTheKids

final class LevelDefinitionTests: XCTestCase {
    func testEveryLevelIsWellFormed() {
        for level in LevelDefinition.all {
            let name = level.id.rawValue
            XCTAssertGreaterThan(level.rows, 0, name)
            XCTAssertTrue(level.layout.allSatisfy { $0.count == level.cols }, "\(name): ragged layout")
            XCTAssertEqual(level.roomLayout.count, level.rows, "\(name): room map height")
            XCTAssertTrue(level.roomLayout.allSatisfy { $0.count == level.cols }, "\(name): room map width")
            for row in level.roomLayout {
                for letter in row {
                    XCTAssertNotNil(Room(mapLetter: letter), "\(name): unknown room letter \(letter)")
                }
            }
            XCTAssertTrue(level.isFloor(level.start), "\(name): start is not open floor")
            for plate in level.pressurePlates {
                XCTAssertTrue(level.isFloor(plate), "\(name): pressure plate \(plate) is not open floor")
            }
            for f in level.furniture {
                for t in f.tiles {
                    XCTAssertEqual(level.character(at: t), ".", "\(name): \(f.label) sits on a wall")
                }
            }
            for s in level.sleepers {
                XCTAssertEqual(level.room(x: s.x, y: s.y), s.room, "\(name): \(s.id) is in the wrong room")
            }
        }
    }

    /// The room map must match the hard-coded rules the game used before levels existed.
    func testClassicRoomMapMatchesOriginalRules() {
        func original(_ x: Int, _ y: Int) -> Room {
            if (1...3).contains(y) {
                if x <= 4 { return .master }
                if (6...9).contains(x) { return .baby }
                if x >= 11 { return .bath }
            }
            if (4...6).contains(y) { return .hall }
            if (7...9).contains(y) && x <= 5 { return .kid }
            if y >= 11 && x <= 5 { return .living }
            return .kitchen
        }
        let level = LevelDefinition.classicMorning
        for y in 0..<level.rows {
            for x in 0..<level.cols {
                XCTAssertEqual(level.room(at: Tile(x: x, y: y)), original(x, y), "tile (\(x), \(y))")
            }
        }
    }

    func testAttenuation() {
        let level = LevelDefinition.classicMorning
        XCTAssertEqual(level.attenuation(from: .hall, to: .hall), 1)
        XCTAssertEqual(level.attenuation(from: .hall, to: .baby), 0.5)
        XCTAssertEqual(level.attenuation(from: .baby, to: .hall), 0.5)
        XCTAssertEqual(level.attenuation(from: .living, to: .baby), 0.22)
    }

    func testStations() {
        let level = LevelDefinition.classicMorning
        XCTAssertEqual(level.station(at: Tile(x: 4, y: 1)), .dress)
        XCTAssertEqual(level.station(at: Tile(x: 4, y: 14)), .leave)
        XCTAssertEqual(level.station(at: Tile(x: 13, y: 9)), .dog)
        XCTAssertNil(level.station(at: Tile(x: 3, y: 2)))
        XCTAssertEqual(level.frontDoor, Tile(x: 4, y: 14))
    }
}
