import Foundation

enum LevelID: String, CaseIterable, Codable {
    case classicMorning
}

/// A kid asleep somewhere in the level.
struct SleeperSpec {
    let id: String
    /// Used in toasts and end cards, e.g. "The baby".
    let name: String
    /// Short label over the wake meter, e.g. "Maya, 8".
    let meterLabel: String
    let x: Double
    let y: Double
    let room: Room
    /// How easily they wake. 1 is average.
    let sensitivity: Double
    /// End card when this kid wakes up.
    let wokeTitle: String
    let wokeText: String
}

struct DogSpec {
    let name: String
    let bed: Tile
}

/// A morning clock with a deadline. Levels without one have no time limit.
struct LevelClock {
    /// Minutes past 5:00 AM.
    let startMinute: Double
    let deadlineMinute: Double
    /// Game minutes per real second.
    let minutesPerSecond: Double
    /// Shown in the header, e.g. "TRAIN AT 6:15".
    let deadlineLabel: String
    let missedTitle: String
    let missedText: String
}

struct RoomLabel {
    let text: String
    let x: Double
    let y: Double
}

/// Text for the card shown before a level starts.
struct LevelIntro {
    let title: String
    let text: String
    let hint: String
    let startButton: String
}

/// Which rule systems a level switches on. New levels add cases here.
enum MechanicKind {
    case pressurePlates
}

/// Everything that describes one level: the map, who's asleep, the rules in play.
/// The rules themselves live in `GameModel` and the `Mechanic` systems.
struct LevelDefinition: Identifiable {
    let id: LevelID
    let title: String
    let subtitle: String
    let intro: LevelIntro

    /// '#' wall, '.' floor, 'F' front door, 'G' back door to the yard.
    let layout: [String]
    /// One letter per tile naming its room (see `Room.mapLetter`). Same size as `layout`.
    let roomLayout: [String]
    let furniture: [Furniture]
    let roomLabels: [RoomLabel]
    let start: Tile
    let sleepers: [SleeperSpec]
    let dog: DogSpec?
    /// Creaky floorboards.
    let pressurePlates: Set<Tile>
    let checklist: [ChecklistItem]
    /// Must be done before the front door works, with the message shown if not.
    let leaveRequirement: (item: ChecklistItem, message: String)?
    let clock: LevelClock?
    let mechanics: [MechanicKind]

    // Derived from the above in `init`.
    let cols: Int
    let rows: Int
    let furnitureIndex: [Tile: Int]
    private let grid: [[Character]]
    private let roomGrid: [[Room]]
    private let adjacentRooms: Set<String>

    init(id: LevelID, title: String, subtitle: String, intro: LevelIntro,
         layout: [String], roomLayout: [String], furniture: [Furniture], roomLabels: [RoomLabel],
         start: Tile, sleepers: [SleeperSpec], dog: DogSpec?, pressurePlates: Set<Tile>,
         adjacentRooms: [(Room, Room)], checklist: [ChecklistItem],
         leaveRequirement: (item: ChecklistItem, message: String)?, clock: LevelClock?,
         mechanics: [MechanicKind]) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.intro = intro
        self.layout = layout
        self.roomLayout = roomLayout
        self.furniture = furniture
        self.roomLabels = roomLabels
        self.start = start
        self.sleepers = sleepers
        self.dog = dog
        self.pressurePlates = pressurePlates
        self.checklist = checklist
        self.leaveRequirement = leaveRequirement
        self.clock = clock
        self.mechanics = mechanics

        grid = layout.map { Array($0) }
        rows = grid.count
        cols = grid.first?.count ?? 0
        roomGrid = roomLayout.map { row in row.map { Room(mapLetter: $0) ?? .hall } }
        self.adjacentRooms = Set(adjacentRooms.map { Self.pairKey($0.0, $0.1) })

        var index: [Tile: Int] = [:]
        for (i, f) in furniture.enumerated() {
            for t in f.tiles { index[t] = i }
        }
        furnitureIndex = index
    }

    // MARK: - Map queries

    var frontDoor: Tile? { tiles(where: "F").first }

    func inBounds(_ t: Tile) -> Bool {
        t.x >= 0 && t.y >= 0 && t.x < cols && t.y < rows
    }

    func character(at t: Tile) -> Character {
        inBounds(t) ? grid[t.y][t.x] : "#"
    }

    /// Open floor with no furniture on it.
    func isFloor(_ t: Tile) -> Bool {
        character(at: t) == "." && furnitureIndex[t] == nil
    }

    func station(at t: Tile) -> Station? {
        switch character(at: t) {
        case "F": return .leave
        case "G": return .dog
        default: return furnitureIndex[t].flatMap { furniture[$0].station }
        }
    }

    func room(at t: Tile) -> Room {
        guard t.y >= 0, t.y < roomGrid.count, t.x >= 0, t.x < roomGrid[t.y].count else { return .hall }
        return roomGrid[t.y][t.x]
    }

    func room(x: Double, y: Double) -> Room {
        room(at: Tile(x: Int(x.rounded()), y: Int(y.rounded())))
    }

    /// Rooms that share a doorway or a thin wall let more sound through.
    func attenuation(from a: Room, to b: Room) -> Double {
        if a == b { return 1 }
        return adjacentRooms.contains(Self.pairKey(a, b)) ? 0.5 : 0.22
    }

    private func tiles(where c: Character) -> [Tile] {
        var out: [Tile] = []
        for (y, row) in grid.enumerated() {
            for (x, ch) in row.enumerated() where ch == c { out.append(Tile(x: x, y: y)) }
        }
        return out
    }

    private static func pairKey(_ a: Room, _ b: Room) -> String {
        [a.rawValue, b.rawValue].sorted().joined(separator: "|")
    }
}

extension LevelDefinition {
    /// Every level in play order. The level select screen shows these.
    static let all: [LevelDefinition] = [.classicMorning]

    static func level(_ id: LevelID) -> LevelDefinition {
        all.first { $0.id == id } ?? .classicMorning
    }
}
