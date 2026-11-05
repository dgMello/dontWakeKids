import Foundation

/// A grid square in a level. (0,0) is the top-left corner; y grows downward.
struct Tile: Hashable {
    var x: Int
    var y: Int

    var neighbors: [Tile] {
        [Tile(x: x + 1, y: y), Tile(x: x - 1, y: y), Tile(x: x, y: y + 1), Tile(x: x, y: y - 1)]
    }
}

enum Room: String, CaseIterable {
    case master, baby, bath, hall, kid, kitchen, living

    /// The letter used for this room in a level's `roomLayout`.
    var mapLetter: Character {
        switch self {
        case .master: return "M"
        case .baby: return "B"
        case .bath: return "T"
        case .hall: return "H"
        case .kid: return "K"
        case .kitchen: return "C"
        case .living: return "L"
        }
    }

    init?(mapLetter: Character) {
        guard let room = Room.allCases.first(where: { $0.mapLetter == mapLetter }) else { return nil }
        self = room
    }
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
