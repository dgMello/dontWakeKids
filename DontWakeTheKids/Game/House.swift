import Foundation

/// A grid square in the house. (0,0) is the top-left corner; y grows downward.
struct Tile: Hashable {
    var x: Int
    var y: Int

    var neighbors: [Tile] {
        [Tile(x: x + 1, y: y), Tile(x: x - 1, y: y), Tile(x: x, y: y + 1), Tile(x: x, y: y - 1)]
    }
}

enum Room: String {
    case master, baby, bath, hall, kid, kitchen, living
}

/// Something you can stand next to and use.
enum Station: String {
    case dress, teeth, shower, coffee, lunch, dog, leave
}

struct Furniture {
    enum Kind { case plain, bed, crib, kidBed }

    let x: Int
    let y: Int
    let w: Int
    let h: Int
    let label: String
    let station: Station?
    let kind: Kind
    let colorHex: UInt32

    var tiles: [Tile] {
        var out: [Tile] = []
        for i in 0..<w {
            for j in 0..<h {
                out.append(Tile(x: x + i, y: y + j))
            }
        }
        return out
    }
}

/// The level: walls, rooms, furniture and creaky boards.
enum House {
    // '#' wall, '.' floor, 'F' front door, 'G' back door to the yard
    static let layout: [String] = [
        "##############",
        "#....#....#..#",
        "#....#....#..#",
        "#....#....#..#",
        "##.#####.##.##",
        "#............#",
        "###.####.#####",
        "#.....#......#",
        "#.....#......#",
        "#.....#......G",
        "#######......#",
        "#............#",
        "#.....#......#",
        "#.....#......#",
        "####F#########",
    ]

    static let cols = 14
    static let rows = 15
    static let grid: [[Character]] = layout.map { Array($0) }

    static let furniture: [Furniture] = [
        Furniture(x: 1, y: 1, w: 2, h: 2, label: "Bed", station: nil, kind: .bed, colorHex: 0x3C4677),
        Furniture(x: 4, y: 1, w: 1, h: 1, label: "Closet", station: .dress, kind: .plain, colorHex: 0x4A3F6B),
        Furniture(x: 6, y: 1, w: 2, h: 1, label: "", station: nil, kind: .crib, colorHex: 0x3D4A7A),
        Furniture(x: 11, y: 1, w: 1, h: 1, label: "Sink", station: .teeth, kind: .plain, colorHex: 0x3F6A88),
        Furniture(x: 12, y: 1, w: 1, h: 2, label: "Shower", station: .shower, kind: .plain, colorHex: 0x35607E),
        Furniture(x: 1, y: 7, w: 2, h: 1, label: "", station: nil, kind: .kidBed, colorHex: 0x5A3F6E),
        Furniture(x: 9, y: 7, w: 2, h: 1, label: "Coffee", station: .coffee, kind: .plain, colorHex: 0x5A4A3A),
        Furniture(x: 12, y: 7, w: 1, h: 1, label: "Fridge", station: .lunch, kind: .plain, colorHex: 0x6C7186),
        Furniture(x: 9, y: 10, w: 2, h: 2, label: "Table", station: nil, kind: .plain, colorHex: 0x4D3E34),
        Furniture(x: 1, y: 11, w: 1, h: 3, label: "Couch", station: nil, kind: .plain, colorHex: 0x3A4A6A),
    ]

    static let furnitureIndex: [Tile: Int] = {
        var map: [Tile: Int] = [:]
        for (i, f) in furniture.enumerated() {
            for t in f.tiles { map[t] = i }
        }
        return map
    }()

    static let start = Tile(x: 3, y: 2)
    static let dogBed = Tile(x: 3, y: 12)
    static let frontDoor = Tile(x: 4, y: 14)
    static let backDoor = Tile(x: 13, y: 9)

    static let creakyBoards: Set<Tile> = [
        Tile(x: 3, y: 3), Tile(x: 4, y: 5), Tile(x: 7, y: 5), Tile(x: 10, y: 5), Tile(x: 3, y: 6),
        Tile(x: 10, y: 8), Tile(x: 8, y: 11), Tile(x: 5, y: 12), Tile(x: 2, y: 9),
    ]

    static let roomLabels: [(text: String, x: Double, y: Double)] = [
        ("Your room", 2.0, 3.1), ("Nursery", 7.5, 2.1), ("Bath", 11.0, 3.1), ("Hall", 5.5, 5.0),
        ("Maya's room", 3.0, 8.8), ("Kitchen", 9.5, 12.2), ("Living room", 3.0, 10.7), ("Front door", 4.0, 13.1),
    ]

    static func inBounds(_ t: Tile) -> Bool {
        t.x >= 0 && t.y >= 0 && t.x < cols && t.y < rows
    }

    static func character(at t: Tile) -> Character {
        inBounds(t) ? grid[t.y][t.x] : "#"
    }

    /// Open floor with no furniture on it.
    static func isFloor(_ t: Tile) -> Bool {
        character(at: t) == "." && furnitureIndex[t] == nil
    }

    static func station(at t: Tile) -> Station? {
        switch character(at: t) {
        case "F": return .leave
        case "G": return .dog
        default: return furnitureIndex[t].flatMap { furniture[$0].station }
        }
    }

    static func room(x: Double, y: Double) -> Room {
        let x = Int(x.rounded())
        let y = Int(y.rounded())
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

    /// Rooms that share a doorway or a thin wall let more sound through.
    private static let adjacent: Set<String> = [
        "hall|master", "baby|hall", "bath|hall", "hall|kid", "hall|kitchen",
        "kitchen|living", "baby|master", "baby|bath", "kid|living", "kid|kitchen",
    ]

    static func attenuation(from a: Room, to b: Room) -> Double {
        if a == b { return 1 }
        let key = [a.rawValue, b.rawValue].sorted().joined(separator: "|")
        return adjacent.contains(key) ? 0.5 : 0.22
    }
}
