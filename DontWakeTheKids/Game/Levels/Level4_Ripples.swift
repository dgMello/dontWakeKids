import Foundation

extension LevelDefinition {
    /// L4: cross Maya's room and back. When the glass ripples, stop.
    static let ripples = LevelDefinition(
        id: .ripples,
        title: "Ripples",
        subtitle: "When the water moves, you don't.",
        intro: LevelIntro(
            title: "The book is due today",
            text: "Get the library book from Maya's shelf and get back out the door.",
            hint: "Watch the glass on the nightstand. When rings spread across it, Maya is stirring: hit Freeze and don't move until they stop.",
            startButton: "Step inside"
        ),
        layout: [
            "##############",
            "#............#",
            "#............#",
            "#............#",
            "#............#",
            "#............#",
            "#............#",
            "#............#",
            "#............#",
            "#............#",
            "#............#",
            "#............#",
            "#............#",
            "#............#",
            "##F###########",
        ],
        // K Maya's room
        roomLayout: Array(repeating: "KKKKKKKKKKKKKK", count: 15),
        furniture: [
            Furniture(x: 1, y: 6, w: 2, h: 1, label: "", station: nil, kind: .kidBed, colorHex: 0x5A3F6E),
            Furniture(x: 1, y: 5, w: 1, h: 1, label: "", station: nil, kind: .plain, colorHex: 0x4D3E34),
            Furniture(x: 10, y: 1, w: 3, h: 1, label: "Books", station: .book, kind: .plain, colorHex: 0x4A3F6B),
            Furniture(x: 6, y: 3, w: 1, h: 5, label: "Dresser", station: nil, kind: .plain, colorHex: 0x5A4A3A),
            Furniture(x: 8, y: 9, w: 3, h: 2, label: "Toy chest", station: nil, kind: .plain, colorHex: 0x4D3E34),
            Furniture(x: 4, y: 11, w: 2, h: 2, label: "Desk", station: nil, kind: .plain, colorHex: 0x3A4A6A),
        ],
        roomLabels: [RoomLabel(text: "Maya's room", x: 3.0, y: 2.5)],
        start: Tile(x: 2, y: 13),
        sleepers: [
            SleeperSpec(id: "maya", name: "Maya", meterLabel: "Maya, 8", x: 1.5, y: 6, room: .kid,
                        sensitivity: 1.2, wokeTitle: "Maya is up",
                        wokeText: "\u{201C}Why are you holding my book?\u{201D} Morning over."),
        ],
        dog: nil,
        pressurePlates: [Tile(x: 4, y: 8), Tile(x: 9, y: 6), Tile(x: 7, y: 2)],
        adjacentRooms: [],
        checklist: [.book],
        leaveRequirement: (item: .book, message: "Not without the library book"),
        clock: nil,
        mechanics: [
            .pressurePlates,
            .ripples(RippleSpec(glass: Tile(x: 1, y: 5), truckAt: 4, truckLength: 1.6, calmGap: 5...9,
                                warning: 0.8, stirLength: 2...4, stepPenalty: 30, taskPenaltyPerSecond: 25)),
        ],
        exitName: "Slip out the door",
        starRules: .quiet(under: 35, outro: LevelOutro(
            silentTitle: "Silent",
            silentText: "Book in hand. Maya never knew.",
            closeCallTitle: "Close call",
            closeCallText: "You got the book, but Maya nearly caught you."
        ))
    )
}
