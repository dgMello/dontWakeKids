import Foundation

extension LevelDefinition {
    /// L1, the tutorial: creaky boards and the noise meter, then a decoy swap and a race to the door.
    static let lostNap = LevelDefinition(
        id: .lostNap,
        title: "Raiders of the Lost Nap",
        subtitle: "Swap the bunny. Beat the ball to the door.",
        intro: LevelIntro(
            title: "The bunny must be washed",
            text: "Take a decoy from the shelf, swap it for the bunny on the toddler's bed, and get out the door.",
            hint: "Tap the floor to walk. The shimmering boards creak, and tiptoe keeps them quiet. Watch the meter.",
            startButton: "Begin the heist"
        ),
        layout: [
            "##############",
            "#.....#....#.#",
            "#.....#....#.#",
            "#.....#....#.#",
            "#.....#....#.#",
            "###.#####.##.#",
            "#............#",
            "#............#",
            "######.#####.#",
            "#............#",
            "#............#",
            "#............#",
            "#............#",
            "#............#",
            "#####F########",
        ],
        // B nursery, T linen closet, H hall, L playroom
        roomLayout: [
            "HHHHHHHHHHHHHH",
            "BBBBBBTTTTTHHH",
            "BBBBBBTTTTTHHH",
            "BBBBBBTTTTTHHH",
            "BBBBBBTTTTTHHH",
            "HHHHHHHHHHHHHH",
            "HHHHHHHHHHHHHH",
            "HHHHHHHHHHHHHH",
            "HHHHHHHHHHHHHH",
            "LLLLLLLLLLLLLL",
            "LLLLLLLLLLLLLL",
            "LLLLLLLLLLLLLL",
            "LLLLLLLLLLLLLL",
            "LLLLLLLLLLLLLL",
            "LLLLLLLLLLLLLL",
        ],
        furniture: [
            Furniture(x: 1, y: 1, w: 2, h: 1, label: "", station: .swap, kind: .kidBed, colorHex: 0x5A3F6E),
            Furniture(x: 7, y: 1, w: 3, h: 1, label: "Shelf", station: .shelf, kind: .plain, colorHex: 0x4A3F6B),
            Furniture(x: 9, y: 10, w: 2, h: 2, label: "Toys", station: nil, kind: .plain, colorHex: 0x4D3E34),
            Furniture(x: 1, y: 10, w: 1, h: 3, label: "Couch", station: nil, kind: .plain, colorHex: 0x3A4A6A),
        ],
        roomLabels: [
            RoomLabel(text: "Nursery", x: 3.0, y: 4.0), RoomLabel(text: "Linen closet", x: 8.5, y: 3.5),
            RoomLabel(text: "Hall", x: 9.0, y: 6.5), RoomLabel(text: "Playroom", x: 8.0, y: 12.3),
        ],
        start: Tile(x: 9, y: 3),
        sleepers: [
            SleeperSpec(id: "toddler", name: "The toddler", meterLabel: "Toddler", x: 1.5, y: 1, room: .baby,
                        sensitivity: 1.6, wokeTitle: "The toddler is up",
                        wokeText: "\u{201C}BUNNY?\u{201D} The nap is lost."),
        ],
        dog: nil,
        pressurePlates: [
            Tile(x: 9, y: 5),    // the closet doorway: one creak you can't avoid
            Tile(x: 3, y: 3),
            Tile(x: 4, y: 6),
            Tile(x: 6, y: 11),
        ],
        adjacentRooms: [(.baby, .hall), (.bath, .hall), (.hall, .living), (.baby, .bath), (.baby, .living)],
        checklist: [.decoy, .swap],
        leaveRequirement: (item: .swap, message: "You came for the bunny"),
        clock: nil,
        mechanics: [
            .pressurePlates,
            .decoySwap(DecoySpec(prize: Tile(x: 2, y: 1), correct: .socks, wrongWeightNoise: 45)),
            .chase(ChaseSpec(path: [Tile(x: 12, y: 1), Tile(x: 12, y: 13), Tile(x: 5, y: 13)],
                             speed: 3.5, trigger: .swap, delay: 0.8, bumpNoise: 140)),
        ],
        exitName: "Slip out the door",
        platesVisible: true,
        starRules: .quiet(under: 35, outro: LevelOutro(
            silentTitle: "Silent",
            silentText: "The bunny is yours and nobody stirred.",
            closeCallTitle: "Close call",
            closeCallText: "You got the bunny, but that was loud."
        ))
    )
}
